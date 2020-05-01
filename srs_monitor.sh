#!/bin/bash

#-----------------------------------------------------------------------#
# ScriptsName: srs_monitor.sh                                           #
# ScriptsPath:/github/scripts/srs_monitor.sh                            #
# Purpose: monitor all node srs program be alive if dead then start it  #
# Edition: 1.0                                                          #
# CreateDate:2016-11-22 20:28                                           #
# Author: Payne Zheng <zzuai520@live.com>                               #
#-----------------------------------------------------------------------#

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

ip=$(awk -F ' |;' '/bind/{print $2}' /etc/nginx/node.conf)
groupName="PLCDN-SUPPORT"
test ! -f /dev/shm/crossdomain.xml && cp /root/scripts/crossdomain.xml /dev/shm/
pgrep srs 
if [ $? -eq 0 ]; then
    exit
else
    cd /opt/srs/trunk
    ./objs/srs -c conf/sz.vpcdn.com.conf
    pgrep srs && stat=OK || stat=Failed
    msg=$(echo -e ">PROBLEM:\nHOST: $ip\n-------------------------\n SRS PROGRAM IS DEAD !!!\n-------------------------\nACTION: restarted $stat \nTIME: $(date '+%Y-%d-%m %H:%M:%S')")
    test "$stat" == "OK" && groupName="PLCDN-STATUS" 
    report "$msg" "$groupName"
fi
