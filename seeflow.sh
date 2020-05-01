#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: seeflow.sh                                       #
# ScriptsPath:/root/scripts/seeflow.sh                          #
# Purpose: View ethcard in and out Flow bandwidth               #
# Edition: 1.0                                                  #
# CreateDate:2016-06-02 10:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

localeth=$(mktemp)
cat /proc/net/dev | awk -F ":" 'NR>2{print $1}'|column -t > $localeth

Help (){
    echo "Usege: You have entered the network card device does not exist, please re-enter"
    echo "Try: seeflow $(cat $localeth | awk '{printf $0"|"}')"
    exit 1
}

cleanup (){
    rm -f $localeth
}

test $# -ne 1 && Help
grep $1 $localeth
test $? -ne 0 && Help
cleanup
#grep -qP '^eth[0-9]$|^bond0$' <<<"$1"  && Help

while [ "1" ]
do
    eth=$1
    INpre=$(cat /proc/net/dev | awk /$eth/'{print $2}')
    OUTpre=$(cat /proc/net/dev | awk /$eth/'{print $10}')
    sleep 1
    INnext=$(cat /proc/net/dev | awk /$eth/'{print $2}')
    OUTnext=$(cat /proc/net/dev | awk /$eth/'{print $10}')
    clear
    echo -e "\t IN  $(date +%k:%M:%S)  OUT"
    IN=$((${INnext}-${INpre}))
    OUT=$((${OUTnext}-${OUTpre}))
    if [[ $IN -lt 1024 ]];then
        IN="${IN}B/s"
    elif [[ $IN -gt 1048576 ]];then
        IN=$(echo $IN | awk '{print $1/1048576*8 "MB/s"}')
    else
        IN=$(echo $IN | awk '{print $1/1024*8 "KB/s"}')
    fi
        if [[ $OUT -lt 1024 ]];then
           OUT="${OUT}B/s"
        elif [[ $OUT -gt 1048576 ]];then
           OUT=$(echo $OUT | awk '{print $1/1048576*8 "MB/s"}')
        else
           OUT=$(echo $OUT | awk '{print $1/1024*8 "KB/s"}')
        fi
           echo -e "$eth \t $IN    $OUT "
done
