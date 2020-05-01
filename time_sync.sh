#!/bin/bash

#--------------------------------------------------------------------#
# ScriptsName: time_sync.sh                                          #
# ScriptsPath:/github/scripts/time_sync.sh                           #
# Purpose: Synchronize all the server time to keep the time precise  #
# Edition: 1.0                                                       #
# CreateDate:2016-11-17 10:28                                        #
# Author: Payne Zheng <zzuai520@live.com>                            #
#--------------------------------------------------------------------#

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

timeServers=$(mktemp)
ip=$(/sbin/ifconfig | grep "inet addr" | grep -v 127.0.0.1 | awk '{print $2}' | tr -d "addr:" | head -1)
Time=$(date "+%Y-%m-%d %H:%M:%S")
msg=$(echo -e ">TIME SYNC FAILED \nHOST: $ip \nTIME:$Time")

cat > $timeServers <<EOF
time.nist.gov
time.nuri.net
tick.greyware.com
0.asia.pool.ntp.org
1.asia.pool.ntp.org
2.asia.pool.ntp.org
3.asia.pool.ntp.org
0.pool.ntp.org
1.pool.ntp.org
2.pool.ntp.org
3.pool.ntp.org
EOF

i=0
while read timeServer
    do
        /usr/sbin/ntpdate -u -b $timeServer &>>/root/ntpdate.log
        if [ $? -eq 0 ]; then
            /sbin/hwclock -w &>>/root/ntpdate.log
            break
        else
            rdate -s $timeServer
            test $? -eq 0 && { /sbin/hwclock -w &>>/root/ntpdate.log;break; }
        fi
        let i++
        test $i -eq 10 && report "$msg" "PLCDN-STATUS"
    done < "$timeServers"

rm -rf "$timeServers"
