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
nodeIP=$(ifconfig | awk '/eth[0-9]|bond/{getline;gsub(/addr:/,"",$2);print $2}' | sed '/[a-zA-Z]/d')
serverSN=$(dmidecode | grep "Serial Number" | sed -n '1p' | sed s/^[[:space:]]//g)
memorySize=$(dmidecode -t memory | awk '/Size: .* MB/{print $2/1024 "G"}' | head -1)
memoryNum=$(dmidecode -t memory | grep -E "Size: .* MB" | wc -l)
memoryUse=$(free -m | awk '/Mem/{print "used:"$3,"free:"$4}')
cpuMode=$(dmidecode |grep -i cpu | awk '/Version:/{print $2,$3,$4,$5,$7}')
cpuNum=$(cat /proc/cpuinfo| grep "physical id"| sort| uniq| wc -l)
cpuCore=$(cat /proc/cpuinfo| grep "cpu cores"| wc -l)
diskNum=$(fdisk -l | grep -E "Disk \/dev\/sd[a-z]" | wc -l)
diskSize=$(fdisk -l | awk '/Disk \/dev\/sd[a-z]/{print $2,$3,$4}')
diskPartition=$(df -h | awk '/[0-9]%/{print "partition:"$NF,"size:"$(NF-4)}' | column -t)

#software information
systemVersion=$(cat /etc/issue | awk 'NR<2{print $0}')
kernelVersion=$(uname -r)
opensslVersion=$(openssl version)
nginxVersion=$(nginx -v 2>&1)

nitf=/root/$(hostname).data
> $nitf &> /dev/null

echo -e "--> NODEip \n$nodeIP\n$(hostname)\n" >> $nitf
echo -e "$(sed -r -e 's/: /\n/' -e 's/Serial/--> Serial/' <<<$serverSN)\n" >> $nitf
echo -e "--> CPUinfo \n$cpuMode \ntotal: $cpuCore nucleus\n" >> $nitf
echo -e "--> MEMinfo \n$memorySize*$memoryNum\n$memoryUse\n" >> $nitf
echo -e "--> DISKinfo " >> $nitf
echo "$diskSize" >> $nitf
#echo "$diskPartition" >> $nitf
df -h | sed -r '/Filesystem/s/ on//' | \
awk '{if(NF>1)print $(NF-4),$(NF-3),$(NF-2),$(NF-1),$NF}' | \
column -t >> $nitf
echo >> $nitf
echo -e "--> SYSTEMinfo \n$systemVersion" >> $nitf
echo -e "$kernelVersion\n" >> $nitf
echo -e "--> SOFTinfo \n$opensslVersion" >> $nitf
echo -e "$nginxVersion" >> $nitf
cat $nitf
