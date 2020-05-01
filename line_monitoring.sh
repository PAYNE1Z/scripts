#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: line_monitoring.sh                               #
# ScriptsPath:/github/scripts/line_monitoring.sh                #
# Purpose: Monitor DRMS Unicom and mobile lines are norma       #
# Edition: 1.1                                                  #
# CreateDate:2016-09-30 13:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

report() {
    local groupName apiUrl msg
    #groupName="PLCDN-SUPPORT"
    #groupName="PLCDN-STATUS"
    apiUrl="http://push.plcdn.net:7890/20160128"
    groupName=$1
    msg=$2
    wget -q --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null
}

cmcc_unreachable=$(mktemp /tmp/tmp-cmcc-XXXXX)
cucc_unreachable=$(mktemp /tmp/tmp-cucc-XXXXX)
cuccip=$(mktemp)
cmccip=$(mktemp)

cat > $cuccip <<EOF
112.123.159.5
58.20.31.163
123.134.94.38
211.91.140.171
124.163.220.85
58.255.173.10
182.118.73.8
218.60.25.114
EOF

cat > $cmccip <<EOF
111.11.7.177
223.99.254.211
223.111.14.236
183.250.186.8
117.177.105.104
112.26.47.17
183.240.18.66
111.23.12.226
EOF

while read ip
do
    ping -c 3 $ip &>/dev/null
    if [ $? -eq 0 ]; then
        continue
    else
        echo $ip >> $cmcc_unreachable
    fi
done < "$cmccip"

failedCmccNum=$(wc -l $cmcc_unreachable | awk '{print $1}')
TIME=$(date "+%Y-%m-%d %H:%M:%S")
if [ "$failedCmccNum" -ge 3 ]; then
    msg=$(echo -e "ERROR:\nTIME:$TIME\n--------------------\n+>CMCC-line unreachable\n--------------------\nUnreachableIP:\n$(cat $cmcc_unreachable)\n--------------------\nMsg From BJZW-DRMS")
    report "PLCDN-SUPPORT" "$msg"
fi

while read ip
do
    ping -c 3 $ip &>/dev/null
    if [ $? -eq 0 ]; then
        continue
    else
        echo $ip >> $cucc_unreachable
    fi
done < "$cuccip"

failedCuccNum=$(wc -l $cucc_unreachable | awk '{print $1}')
TIME=$(date "+%Y-%m-%d %H:%M:%S")
if [ "$failedCuccNum" -ge 3 ]; then
    msg=$(echo -e "ERROR:\nTIME:$TIME\n--------------------\n+>CUCC-line unreachable\n--------------------\nUnreachableIP:\n$(cat $cucc_unreachable)\n--------------------\nMsg From BJZW-DRMS")
    report "PLCDN-SUPPORT" "$msg"
fi

rm -rf $cmcc_unreachable
rm -rf $cucc_unreachable
rm -rf $cmccip
rm -rf $cuccip
