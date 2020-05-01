#!/bin/bash

#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-07-12 10:43:41
# Location: Shenzhen
# Desc:     monitor import shell error output 
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

logFile=/root/debug.log
lastSizeFile=/root/lastsize.txt

test ! -f $lastSizeFile && echo 0 > $lastSizeFile
read lastSize < $lastSizeFile
newSize=$(du -b $logFile|awk '{print $1}')
diffSize=$(($newSize-$lastSize))

test $diffSize -lt 10 && exit

tail -c $diffSize $logFile | sort | uniq | \
while read line
do
    msg=$(echo -e "log Import problem:\n--------------------\n\
Details:\n---------------------\n\
### $line ###\n--------------------\n\
Time: $(date '+%Y-%m-%d %H:%M:%S')\n\
From: LOG1 SERVER.43.241.11.42.BJ")
    report "$msg" "PLCDN-SUPPORT"
done
   
echo "$newSize" > $lastSizeFile 
