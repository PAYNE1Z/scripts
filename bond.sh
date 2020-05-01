#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: bond.sh                                          #
# ScriptsPath:/root/scripts/bond.sh                             #
# Purpose: Dual network bonding                                 #
# Edition: 1.0                                                  #
# CreateDate:2016-06-02 19:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

netIP=$1
netMask=$2
netGateway=$3
netDNS=$4
netDevice0=$5
netDevice1=$6
bondMode=$7
localDevice=$(mktemp)
bond0=/etc/sysconfig/network-scripts/ifcfg-bond0
config0=/etc/sysconfig/network-scripts/ifcfg-$netDevice0
config1=/etc/sysconfig/network-scripts/ifcfg-$netDevice1
bondetc=/etc/modprobe.d/bond0.conf

Help() {
    echo "Usege: Invalid parameter , Please re-enter"
    echo "Try: bond.sh IP NETMASK GATEWAY DNS DEVICE0 DEVICE1 bondmode[0:LB|1:AB|6:ALB]"
    exit 1
}

Help1() {
    echo "Usege: You have entered the network card device does not exist, please re-enter "
    echo "Try: $(cat  $localDevice)"
    exit 1
}

Netrestart() {
    /etc/init.d/network restart
}

Success() {
    echo "Double network card binding success"
}

Read() {
    read -p "Configure the correct, please press y " num
    test $num != y && exit
}

Verification() {
    cat /proc/net/bonding/bond0
}


cat /proc/net/dev | awk -F ":" 'NR>2{print $1}' | column -t | awk '{printf $0"|"}' > $localDevice
test $# -ne 7 && Help
grep -E "\b$5\b" $localDevice &> /dev/null
test $? -ne 0 && Help1
grep -E "\b$6\b" $localDevice &> /dev/null
test $? -ne 0 && Help1
grep -qP "0|1" <<<$7 && Help

echo -e "\
alias bond0 bonding\n\
options bond0 miimon=100 mode=$7" >> $bondetc
test $? -eq 0 && cat $bondetc
#Read

echo -e "\
DEVICE=bond0\n\
BOOTPROTO=static\n\
IPADDR=$netIP\n\
NETMASK=$netMask\n\
GATEWAY=$netGateway\n\
DNS1=$netDNS\n\
NM_CONTROLLED=no\n\
ONBOOT=yes" > $bond0
test $? -eq 0 && cat $bond0
#Read

sed -i -r '/HWADDR|UUID/!d' $config0
echo -e "\
DEVICE=$netDevice0\n\
TYPE=Ethernet\n\
BOOTPROTO=none\n\
NM_CONTROLLED=no\n\
ONBOOT=yes\n\
MASTER=bond0\n
SLAVE=yes" >> $config0
test $? -eq 0 && cat $config0
#Read

sed -i -r '/HWADDR|UUID/!d' $config1
echo -e "\
DEVICE=$netDevice1\n\
TYPE=Ethernet\n\
BOOTPROTO=none\n\
NM_CONTROLLED=no\n\
ONBOOT=yes\n\
MASTER=bond0\n
SLAVE=yes" >> $config1
test $? -eq 0 && cat $config1
#Read

Netrestart
Verification
test $? -eq 0 && Success
rm -f $localDevice
