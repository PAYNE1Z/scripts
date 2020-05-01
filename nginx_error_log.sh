#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: nginx_error_log.sh                               #
# ScriptsPath:/github/scripts/nginx_error_log.sh                #
# Purpose: monitor nginx error log                              #
#          report exceptions and respond to actions.            #
# Edition: 1.0                                                  #
# CreateDate:2016-09-09 00:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

report() {
    local groupName apiUrl msg
    #groupName="PLCDN-SUPPORT"
    #groupName="PLCDN-STATUS"
    apiUrl="http://push.plcdn.net:7890/20160128"
    msg=$1
    groupName=$2
    wget -q --tries=1 --timeout=30 --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null
}

ip=$(/sbin/ifconfig | grep "addr:" | grep -vE  "127.0.0.1|inet6" | awk '{print $2}' | cut -d ':' -f 2)
host=$(hostname)
ngerrorlog=/var/log/nginx/error.log
log_dir=/tmp/nginx_error_log
log_file=$log_dir/errlog.txt
lastsizefile=$log_dir/lastsize.txt
domainlist=$log_dir/domain.txt
logsize=$(du -b "$ngerrorlog" | awk '{print $1}')
Time=$(date "+%Y-%m-%d %H:%M:%S")
test -d $log_dir || mkdir $log_dir

if [ -f $lastsizefile ]; then
    read lastsize < $lastsizefile
    newsize=$((logsize-lastsize))
else
    lastsize=$logsize
    newsize=$(($logsize-$lastsize))
fi

echo $logsize > $lastsizefile
#test $newsize -lt 30 && exit 0
ps -ef|grep "cache loader" | grep -w 1 | awk '{print $2}' | xargs kill -9
ps -ef|grep "shutting down" | awk '{print $2}' | xargs kill -9
exit
pgrep nginx || /etc/init.d/nginx start

errStr1="zero size buf in output"
errStr2="recv\(\) failed \(111: Connection refused\)"

tail -c $newsize $ngerrorlog | grep -E "$errStr1|$errStr2" > ${log_file}
grep "$errStr1" ${log_file} | grep -v "referrer" | awk '{print $NF}' | tr -d '"' | sort | uniq > ${domainlist}
domain=$(cat ${domainlist})
grep -q "$errStr1" ${log_file}
sta1=1
sta2=$(grep -E "$errStr2" ${log_file} | wc -l)

if [ $sta1 -eq 0 ]; then
    if [ ! -z "$domain" ]; then
        groupName="PLCDN-STATUS"
        sta=ok
        /etc/init.d/nginx restart
        test $? -eq 0 || { sta=failed ; groupName="PLCDN-SUPPORT" ; /etc/init.d/nginx restart; }
        msg=$(echo -e "PROBLEM:\nIP: ${ip}\nHOST: ${host}\n--------------------- \
        \nNGINX ERROR: \
        \n=> $errStr1\n--------------------- \
        \nAffected domain:\n$(cat ${domainlist})\n--------------------- \
        \nACTION:\nNGINX RESTART:\n ===> restart $sta\nTIME: $Time")
        report "$msg" "$groupName"
    else
        groupName="PLCDN-STATUS"
        msg=$(echo -e "PROBLEM:\nIP: ${ip}\nHOST: ${host}\n--------------------- \
        \nNGINX ERROR: \
        \n=> $errStr1\n--------------------- \
        \nAffected domain:\n$(cat ${domainlist})\nTIME: $Time")
        report "$msg" "$groupName"
    fi
fi
if [ $sta2 -ge 500 ]; then
    groupName="PLCDN-STATUS"
    sta=ok
    /etc/init.d/nginx restart
    test $? -eq 0 || { sta=failed ; groupName="PLCDN-SUPPORT" ; /etc/init.d/nginx restart; }
    msg=$(echo -e "PROBLEM:\nIP: ${ip}\nHOST: ${host}\n--------------------- \
    \nNGINX ERROR: \
    \n=> $errStr2\n--------------------- \
    \nACTION:\n>NGINX RESTART:\n ===> restart $sta\nTIME: $Time")
    report "$msg" "$groupName"
fi
echo $logsize > $lastsizefile

i=0
while :
do
    ps -ef | grep nginx | grep worker &>/dev/null
    if test $? -ne 0; then
        /etc/init.d/nginx restart
    else
        exit
    fi
    let i++
    sleep 10
    test $i -eq 10 && exit
done
