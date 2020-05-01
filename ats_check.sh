#!/bin/bash

# ScriptsName: ats_check.sh                                
# ScriptsPath:/root/scripts/ats.check.sh                
# Purpose: monitor ATS server crashes            
# Edition: 1.0                                                  
# CreateDate:2016-05-24 19:31                                   
# Author: Payne Zheng <zzuai520@live.com> 

Normal() {
    echo "2"
}

Abnormal() {
    echo "1"
}

atsPIDfile=/tmp/atspid.txt
Time=$(date +%s)
timeout=1800

if [ ! -s $atsPIDfile ]; then
    managerPID=$(ps -ef |grep ats | awk '/traffic_manager/{print $2}')
    serverPID=$(ps -ef |grep ats | awk '/traffic_server/{print $2}')
    echo "$Time $managerPID $serverPID" > $atsPIDfile
fi

NmPID=$(ps -ef |grep ats | awk '/traffic_manager/{print $2}')
NsPID=$(ps -ef |grep ats | awk '/traffic_server/{print $2}')
Ots=$(awk '{print $1}' $atsPIDfile)
difftime=$(($Time-$Ots))

grep "$NmPID" $atsPIDfile &> /dev/null
one=$?

grep "$NsPID" $atsPIDfile &> /dev/null
two=$?

if [ $one -ne 0 -o $two -ne 0 ]; then
    if [ $difftime -gt $timeout ]; then
        Abnormal
        echo "$Time $NmPID $NsPID" > $atsPIDfile
    else
	Normal
    fi
else
    Normal
fi
