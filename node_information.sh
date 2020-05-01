#!/bin/bash

# ScriptName:node_information.sh
# ScriptsPath:/root/scripts/node_information.sh                
# Purpose: Query server software / hardware information
# Edition: 1.0                                                  
# CreateDate:2016-05-24 13:33                                   
# Author: Payne Zheng <zzuai520@live.com> 

# check soft dmidecode installed
rpm -qa | grep dmidecode &>/dev/null || yum install dmidecode -y 

#hardware information
#nodeIP=$(ifconfig | sed -n '/eth[0-9]|bond/{N;s/.*inet addr://;s/ .*//p}'| sed '/[a-zA-Z]/d')
ethdevice=$(cat /proc/net/dev | awk -F ":" 'NR>2{print $1}'|column -t|awk '{printf $0}')
nodeIP=$(ip a | grep -w inet | grep -v 127.0.0.1 | awk '{print $2}' | awk -F/ '{print $1}')
serverSN=$(dmidecode | grep "Serial Number" | sed -n '1p' | sed s/^[[:space:]]//g)
memorySize=$(dmidecode -t memory | awk '/Size: .* MB/{print $2/1024 "G"}' | head -1)
memoryNum=$(dmidecode -t memory | grep -E "Size: .* MB" | wc -l)
memoryUse=$(free -m | awk '/Mem/{print "used:"$3,"free:"$4}')
cpuMode=$(dmidecode |grep -i cpu | awk '/Version:/{print $2,$3,$4,$5,$7}' | head -1)
cpuNum=$(cat /proc/cpuinfo| grep "physical id"| sort| uniq| wc -l)
cpuCore=$(cat /proc/cpuinfo| grep "cpu cores"| wc -l)
diskNum=$(fdisk -l | grep -E "Disk \/dev\/sd[a-z]" | wc -l)
diskSize=$(fdisk -l | awk '/Disk \/dev\/sd[a-z]/{print $3"GB"}' | sort | uniq -c | awk '{print $2,"* "$1}' | tr '\n' ',')
diskPartition=$(df -h | awk '/[0-9]%/{print "partition:"$NF,"size:"$(NF-4)}' | column -t)

#software information
systemVersion=$(cat /etc/redhat-release)
kernelVersion=$(uname -r)
opensslVersion=$(openssl version)
nginxVersion=$(nginx -v 2>&1)

nitf=/root/$(hostname).data
> $nitf &> /dev/null

echo "$nodeIP,$(hostname)" >> $nitf
echo "$(sed -r -e 's/: /,/' <<<$serverSN | awk -F, '{print $2}')" >> $nitf
echo "$cpuMode * $cpuNum,total: $cpuCore nucleus" >> $nitf
echo "$memorySize * $memoryNum,$memoryUse" >> $nitf
echo -n "$(sed -r 's/\n//' <<<$diskSize)" >> $nitf
df -h | sed -r '/Filesystem/s/ on//' | \
awk '{if(NF>1 && NR>1)print $NF,"Used:"$(NF-1),"Avail:"$(NF-2)}' | \
sort | tr '\n' ',' | sed -r 's/,$/\n/' >> $nitf
echo "$systemVersion,$kernelVersion" >> $nitf
echo "$opensslVersion,$nginxVersion" >> $nitf
cat $nitf
