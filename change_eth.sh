#!/bin/bash

# ScriptsName: change_eth.sh                                
# ScriptsPath:/root/scripts/change_eth.sh                
# Purpose: change network config            
# Edition: 1.0                                                  
# CreateDate:2016-05-17 14:31                                   
# Author: Payne Zheng <zzuai520@live.com> 

Help() {
    echo "usege: You entered the network card device is incorrect, please re-enter"
    echo "Try: chnet szwork|dghome|szhome"
    exit 1
}

Restart() {
    /etc/init.d/network restart &> /dev/null
}

Success() {
    echo -e "$GREEN_COLOR Chnet Success ^_^ $RES"
}

CheckNowStatus() {
    ping -c 1 baidu.com &>/dev/null
    test $? -eq 0 && { echo -e "$RED_COLOR === network now is good, no need to change === $RES"; exit; }
}

test $# -ne 1 && Help
CheckNowStatus
grep -qP '^dgwork$|^dghome$|^szhome$' <<<"$1" || Help

location=$1
device_eth0=/etc/sysconfig/network-scripts/ifcfg-eth0
device_eth1=/etc/sysconfig/network-scripts/ifcfg-eth1
device_eth2=/etc/sysconfig/network-scripts/ifcfg-eth2
device_eth3=/etc/sysconfig/network-scripts/ifcfg-eth3
RED_COLOR='\E[1;33m'
GREEN_COLOR='\E[1;33m'
RES='\E[0m'

case $location in
    "dgwork" )
        sed -i '/ONBOOT/s/no/yes/' $device_eth0 &> /dev/null
        sed -i '/ONBOOT/s/yes/no/' $device_eth2 &> /dev/null
        sed -i '/ONBOOT/s/yes/no/' $device_eth3 &> /dev/null
        ;;

    "dghome" ) 
        sed -i '/ONBOOT/s/no/yes/' $device_eth2 &> /dev/null
        sed -i '/ONBOOT/s/yes/no/' $device_eth0 &> /dev/null
        sed -i '/ONBOOT/s/yes/no/' $device_eth3 &> /dev/null
        ;;

    "szhome" )
        sed -i '/ONBOOT/s/no/yes/' $device_eth3 &> /dev/null
        sed -i '/ONBOOT/s/yes/no/' $device_eth0 &> /dev/null
        sed -i '/ONBOOT/s/yes/no/' $device_eth2 &> /dev/null
        ;;

        * ) 
        Help
        ;;
esac
    
Restart
ping www.baidu.com -c 3 &> /dev/null
test $? -eq 0 && Success
