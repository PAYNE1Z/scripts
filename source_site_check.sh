#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-05-15 15:30:43
# Location: Shenzhen
# Desc:     check back origin site domain analytic 
#

cleanUp() {
    rm -f $domainBackList
}

report() {
    local groupName apiUrl msg
    #groupName="PLCDN-SUPPORT"
    #groupName="PLCDN-STATUS"
    apiUrl="http://push.plcdn.net:7890/20160128"
    msg=$1
    groupName=$2
    wget -q --tries=1 --timeout=30 --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null
}

makeMsg() {
    local mType=$1
    test $mType = xx && { totil=">Sourcesite failure";action="Notice customer..."; }
    test $mType = ok && { totil=">Sourcesite recovery ok";action="Update to $analyticIp"; }
    test $mType = up && { totil=">Sourcesite changed";action="Changed to $analyticIp"; }
    test $mType = no && { totil=">Sourcesite unable resolution";action="Temporary settings $tempIP"; }
    msg=$(echo -e "##### $totil \nOrgsite: $soudom \n \
###### Domain: $(sed -r -e 's/^/ /' -e 's/\s/\n \# /g' <<<$domain) \n From: $localIp \n \
Time: $(date '+%Y-%m-%d %H:%M:%S')\n Action: $action")
}

hostFile=/etc/hosts
upstreamFile=/etc/nginx/webconf.d/http_upstreams.conf
uidFile=/etc/nginx/webconf.d/siteuidlist.txt
localIp=$(awk '/bind/{print $2}' /etc/nginx/node.conf | tr -d ';')
domainBackList=$(mktemp)
tempIP=127.0.0.1

if test -z $1; then
    awk '/server/{print $2}' $upstreamFile | grep -E '[a-z]+' | sed -r 's/:[0-9]+//g' | sort | uniq > $domainBackList
else
    echo $1 > $domainBackList
fi

[ ! -n $domainBackList ] && exit

reloadTag=0
while read soudom
    do
	    domain=$(grep -w $soudom $uidFile | awk '{print $3}')
	    hostAnalyticIp=$(grep -w $soudom $hostFile | awk '{print $1}')
        analyticIp=$(nslookup $soudom 2>/dev/null | grep -vE '#53' | awk '/Address/{print $2}' | head -1)
        if test -z $analyticIp; then
            if grep -qw $soudom $hostFile; then
                echo "failure: hosts exist nothing to do $soudom"
	            #makeMsg xx
                #report "$msg" "PLCDN-SUPPORT"
                test ! -z "$hostAnalyticIp" && continue
                #test "$hostAnalyticIp" = "$tempIP" && continue
                #sed -r -i "/$soudom/s/$hostAnalyticIp/$tempIP/" $hostFile
            else
                echo -e "$tempIP\t $soudom" >> $hostFile
                echo "unable resolution: add $tempIP to hosts in $soudom"
            fi
	        makeMsg no
            report "$msg" "PLCDN-SUPPORT"
        else
            if test "$hostAnalyticIp" = "$tempIP"; then
                sed -r -i "/$soudom/s/$hostAnalyticIp/$analyticIp/" $hostFile
                echo "recovery: update $hostAnalyticIp to $analyticIp in $soudom"
		        makeMsg ok
            	report "$msg" "PLCDN-SUPPORT"
                let reloadTag++
	        elif test -z "$hostAnalyticIp"; then
		        echo -e "$analyticIp\t $soudom" >> $hostFile
                echo "newSourceDom: add $analyticIp $soudom to hosts"
            elif test "$hostAnalyticIp" != "$analyticIp" -a ! -z "$hostAnalyticIp"; then
                nslookup $soudom 2>/dev/null | grep -qw $hostAnalyticIp && \
                { echo "multiple ip: one of them already exists hosts $soudom"; continue; }
                sed -r -i "/$soudom/s/$hostAnalyticIp/$analyticIp/" $hostFile
                echo "changed: customer update $hostAnalyticIp to $analyticIp in $soudom"
		        #makeMsg up
            	#report "$msg" "PLCDN-SUPPORT"
            fi
        fi
    done < $domainBackList
    
test $reloadTag -ne 0 && /etc/init.d/nginx reload

trap cleanUp exit
