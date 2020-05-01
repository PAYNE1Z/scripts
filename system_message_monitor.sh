#!/bin/bash

#-------------------------------------------------------------------------------------#
# ScriptsName: system_monitor.sh                                                      #
# ScriptsPath:/root/scripts/system_monitor.sh                                         #
# Purpose: system monitor find the wrong message to WeChat and push to zabbix page    #
# Edition: 1.0                                                                        #
# CreateDate:2016-06-04 21:17                                                         #
# Author: Payne Zheng <zzuai520@live.com>                                             #
#-------------------------------------------------------------------------------------#

Apicall() {
    local GroupName Content Apiurl
    GroupName="PLCDN-STATUS"
    Apiurl="http://push.plcdn.net:7890/20160128"
    Content=$1
    curl -H "To:$GroupName" "$Apiurl" -d "$Content"
}

Nodeip=$(ifconfig -a | grep -vE "127.0.0.1|inet6" | awk '/inet addr/{print $2}' | tr -d "addr:")
Mslog=/var/log/messages
Dmesglog=/var/log/dmesg
Mlastsizefile=/tmp/.system_mlastsize.txt
Dlastsizefile=/tmp/.system_dlastsize.txt
Difflog=/tmp/.system_diff.log
Pbfile=/tmp/.system_pb.log
Mslogsize=$(du -b $Mslog | awk '{print $1}')
Dmesglogsize=$(du -b $Dmesglog | awk '{print $1}')
K1="[Hardware Error]: section_type"
K2="possible SYN flooding"
K3="dropping packet"
K4="time wait bucket table overflow"
K5="callbacks suppressed"
K6="Too much work at interrupt"
K7="UDP: bad checksum"
K8="UDP: short packet"
K9="transmit timed out"
K10="Reset not complete yet"
K11="Neighbour table overflow"
K12="Transmit error"
K13="Temperature above threshold"
K14="Running in modulated clock mode"
K15="I/O error"
K16="Error reading PHY register"
K17="*BAD*gran_size"

:> $Pbfile

if [ -f "$Mlastsizefile" ]; then
    read Mlastsize < $Mlastsizefile
    Msdiffsize=$(($Mslogsize-Mlastsize))
else
    Mlastsize=$Mslogsize
    Msdiffsize=$(($Mslogsize-$Mlastsize))
fi

if [ -f "$Dlastsizefile" ]; then
    read Dlastsize < $Dlastsizefile
    Dsdiffsize=$(($Dmesglogsize-Dlastsize))
else
    Dlastsize=$Dmesglogsize
    Dsdiffsize=$(($Dmesglogsize-$Dlastsize))
fi

test $Msdiffsize -lt 30 -a $Dsdiffsize -lt 20 && \
echo $Dmesglogsize > $Dlastsizefile && \
echo $Mslogsize > $Mlastsizefile && \
exit 1

tail -c $Msdiffsize $Mslog |\
grep -E "${K1}|${K2}|${K3}|${K4}|${K5}|${K6}|${K7}|${K8}|${K9}|${K10}|${K11}|${K12}|${K13}|${K14}|${K15}|${K16}|${K17}" |\
awk '/callbacks suppressed/{print $7=""}1' | awk '{$1=$2=$3=$4=$5=""}1' |\
sort | uniq | sed -e 's/^\s*//g' -e  '/^$/d' -e 's/^/M: /g' > $Difflog

tail -c $Dsdiffsize $Dmesglog |\
grep -E "${K1}|${K2}|${K3}|${K4}|${K5}|${K6}|${K7}|${K8}|${K9}|${K10}|${K11}|${K12}|${K13}|${K14}|${K15}|${K16}|${K17}" |\
sort | uniq | sed -e 's/^\s*//g' -e  '/^$/d' -e 's/^/D: /g' >> $Difflog

while read line
do
    Msg=$(echo -e "SystemLog:\nNodeIP:\n$Nodeip\n$line")
    echo "$Msg" >> $Pbfile
    Apicall "$Msg"
done < $Difflog

echo $Mslogsize > $Mlastsizefile
echo $Dmesglogsize > $Dlastsizefile
cat $Pbfile
