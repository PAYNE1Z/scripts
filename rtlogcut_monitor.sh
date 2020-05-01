#!/bin/bash

# ScriptsName: rtlogcut_monitor.sh                                           
# ScriptsPath:/github/scripts/rtlogcut_monitor.sh                            
# Purpose: monitor all node rtlogcut program be alive if dead then start it  
# Edition: 1.0                                                          
# CreateDate:2017-08-31 20:28                                          
# Author: Payne Zheng <zzuai520@live.com>                               

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

pgrep rtlogcut 
if [ $? -eq 0 ]; then
    exit
else
    rtlogcut -b -d -c /etc/rtlogcut.cfg
    pgrep rtlogcut && stat=OK || stat=Failed
    msg=$(echo -e "###### PROBLEM:\nHOST: $ip\n ##### RTLOGCUT PROGRAM IS DEAD !!!\nACTION: restarted $stat \nTIME: $(date '+%Y-%d-%m %H:%M:%S')")
    test "$stat" == "OK" && groupName="PLCDN-STATUS" 
    report "$msg" "$groupName"
fi
