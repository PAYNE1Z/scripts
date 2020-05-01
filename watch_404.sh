#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-07-13 19:02:17
# Location: Shenzhen
# Desc:     watch access log check status for 404 to orgsite 
#

report() {
    local groupName apiUrl msg
    #groupName="PLCDN-SUPPORT"
    #groupName="PLCDN-STATUS"
    apiUrl="http://push.plcdn.net:7890/20160128"
    msg=$1
    groupName=$2
    wget -q --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null
}

getDomainID() {
    local domain=$1
    grep -A2 "server_name $domain;" $ngxConf | \
    awk '/site_id/{print $NF}' | tr -d ';'
}

getOrgSite() {
    local domainID=$1
    grep -Ew "^$domainID " $siteOrgList | \
    awk '{$1=$2=$3=$4=""}1' | \
    sed -r -e 's/^\s+//' -e 's/\s+/\n/g' -e 's/&/-/g' | \
    head -1
}

checkOrgSite() {
    local org=$1
    grep -qE '[a-z]' <<<$org && \
    orgSite=$(grep -w "${org/:80/}" /etc/hosts | awk '{print $1":80"}')
}

checkAccStat() {
    local checkText=$1 checkUrl=$2
    accStat=$(awk '/^HTTP\/1.1/ {print $2}' $checkText | head -1)
    if test -z "$accStat" -o "$accStat" -eq "404" -o "$accStat" -gt "400"; then
        return 1
    else
        nodeAccStat=$(curl -I "$checkUrl" -x 127.0.0.1:80 2>/dev/null 2>&1 | awk '/^HTTP\/1.1/ {print $2}')
        test $nodeAccStat -eq 404 && return 0 || return 1
    fi
}

cleanUp() {
    rm -rf $tempText
}

makeMsg() {
local accUrl=$1
msg=$(echo -e "STRANGE 404 ERROR.\n--------------------\n\
Details: \n\
### access source station is OK, but access node is 404. ####\n\
Url: $accUrl\n\
Org: $orgSite\n\
Node: $(awk -F '[ ;]+' '/^\s*bind/ {print $2}' /etc/nginx/node.conf)\n\
Time: $(date '+%Y-%m-%d %H:%M:%S')")
}

ngxLog=/var/log/nginx/bdrz.log
ngxConf=/etc/nginx/webconf.d/servers_upstreams.conf
siteOrgList=/etc/nginx/webconf.d/siteuidlist.txt
probleFile=/var/log/nginx/404.log
tempText=$(mktemp)

tail -F $ngxLog | awk '$10 == 404 {print}' | grep -v 'favicon.ico' | \
#cat /root/access.log | awk '$10 == 404 {print}' | grep -v 'favicon.ico' | \
while read line
    do
       domain=$(awk '{print $1}' <<<$line)
       accUri=$(awk '{print $8}' <<<$line | tr -d '"')
       accUrl="'http://$domain$accUri'"
       domainID=$(getDomainID $domain)
       test -z "$domainID" && continue
       orgSite=$(getOrgSite $domainID)
       checkOrgSite $orgSite
       curl -m 10 -I "$accUrl" -x $orgSite 2>/dev/null &>$tempText
       test $? -ne 0 && continue
       checkAccStat "$tempText" "$accUrl"
       test $? -eq 1 && continue
       makeMsg $accUrl $orgSite
       report "$msg" "PLCDN-SUPPORT"
       echo "$(date '+%Y-%m-%d/%H:%M:%S') $accUrl $orgSite $accStat" | tee -a $probleFile
    done 

trap cleanUp exit
#cat $probleFile
