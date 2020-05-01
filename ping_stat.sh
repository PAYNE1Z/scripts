#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: ping_stat.sh                                     #
# ScriptsPath:/root/scripts/ping_stat.sh                        #
# Purpose: test new node ping all node statistcs                #
# Edition: 1.0                                                  #
# CreateDate:2016-08-23 15:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

Help() {
    echo "Usage: $(basename $0) iplist packets-num yousort(avg|min|max|loss)"
    exit
}

inited() {
    rpm -qa|grep rsync || yum install rsync -y &> /dev/null
}

upload() {
    local server ip file
    server="114.119.10.168"
    ip=$(ifconfig | grep "inet addr" | grep -v 127.0.0.1 | awk '{print $2}' | tr -d "addr:" | head -1)
    file=$1
    rsync -av --contimeout=20 --timeout=20 $file $server::ping_log/$ip/
}

test $# -ne 3 && Help
#inited
iplist=$1
packets=$2
typeset -u yousort=$3
tempfile=$(mktemp)
log_dir=/root/pingstat
test -d ${log_dir} || mkdir ${log_dir}
log_file=${log_dir}/ping_$(date +%m%d%H%M).log

cat ${iplist} | xargs -P 50 -L 1 ping -c "$packets" | grep -A2 "ping statistics" > ${log_file}

sed -i -r 's/^--$//g' ${log_file}
sed -i -r 's/^--- //g' ${log_file}
sed -i -r 's/ ping statistics ---$/,/g' ${log_file}
cat ${log_file} | tr ' |/' ',' > ${tempfile}
sed -i -r 's/^[0-9]+,packets.*received,,//g' ${tempfile}
sed -i -r 's/,time,[0-9]*ms$//g' ${tempfile}
awk -vRS='' 'NF+=0' OFS='' ${tempfile} > ${log_file}
awk -F, '{print $1,"LOSS: "$2,"MIN: "$11,"MAX: "$13,"AVG: "$12}' ${log_file} | column -t > ${tempfile}

case $yousort in
    "AVG")
        sort -nk9 ${tempfile} > ${log_file}
    ;;

    "MIN")
        sort -nk5 ${tempfile} > ${log_file}
    ;;

    "MAX")
        sort -nk7 ${tempfile} > ${log_file}
    ;;

    "LOSS")
        sort -nk3 ${tempfile} > ${log_file}
    ;;
    
	*)
        sort -nk9 ${tempfile} > ${log_file}
    ;;
esac

GREEN_COLOR='\E[1;32m'
RES='\E[0m'
echo -e "\a"
echo -e "${GREEN_COLOR}========== +++ TEST FINISHED +++ ==========${RES}" 
echo -e "${GREEN_COLOR}== TO SEE LOG FILE : ${log_file} ==${RES}" 
echo 

#upload ${log_file}

#if [ $? -eq 0 ]; then
#    echo "${log_file} uploaded ok" >> /tmp/pingstat.log
#else
#    echo "${log_file} uploaded failed" >> /tmp/pingstat.log
#fi

rm -f ${tempfile}
