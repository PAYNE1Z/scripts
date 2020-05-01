#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: pingOne.sh                                       #
# ScriptsPath:/root/scripts/pingOne.sh                          #
# Purpose: test all node ping sitesource or anywhere  ip        #
# Edition: 1.0                                                  #
# CreateDate:2017-04-13 15:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

Help() {
    echo "Usage: $(basename $0) iplist packets-num yousort(avg|min|max|loss) fromip"
    exit
}

showInfo() {
    GREEN_COLOR='\E[1;32m'
    RES='\E[0m'
    echo -e "\a"
    echo -e "${GREEN_COLOR}========== +++ TEST FINISHED +++ ==========${RES}" 
    echo -e "${GREEN_COLOR}== TO SEE LOG FILE : ${log_file} ==${RES}" 
    echo 
}

test $# -ne 4 && Help

#localIP=$(ifconfig  | grep "inet addr" | awk '{print $2}' | grep -v 127.0.0.1 | awk -F: '{print $2}' | head -1)
iplist=$1
packets=$2
typeset -u yousort=$3
fromIP=$4
tempfile=$(mktemp)
log_dir=/root/pingstat
test -d ${log_dir} || mkdir ${log_dir}
log_file=${log_dir}/ping_$(date +%m%d%H%M).log
test -f "$iplist" && cmd="cat" || cmd="echo"

$cmd "$iplist" | xargs -P 50 -L 1 ping -c "$packets" -I $fromIP | grep -A2 "ping statistics" > ${log_file}

#fromIP=$(awk '/^PING/{print $5}' $log_file)
sed -i -r 's/^--$//g' ${log_file}
sed -i -r 's/^--- //g' ${log_file}
sed -i -r 's/ ping statistics ---$/,/g' ${log_file}
cat ${log_file} | tr ' |/' ',' > ${tempfile}
sed -i -r 's/^[0-9]+,packets.*received,,//g' ${tempfile}
sed -i -r 's/,time,[0-9]*ms$//g' ${tempfile}
awk -vRS='' 'NF+=0' OFS='' ${tempfile} > ${log_file}
awk -vip=$fromIP -F, '{OFS=",";print ip,$1,$2,$11,$13,$12}' ${log_file} | column -t > ${tempfile}

case $yousort in
    "AVG")
        sort -t, -nk6 ${tempfile} > ${log_file}
    ;;

    "MIN")
        sort -t, -nk4 ${tempfile} > ${log_file}
    ;;

    "MAX")
        sort -t, -nk5 ${tempfile} > ${log_file}
    ;;

    "LOSS")
        sort -t, -nk3 ${tempfile} > ${log_file}
    ;;
    
	*)
        sort -t, -nk6 ${tempfile} > ${log_file}
    ;;
esac

#showInfo

cat ${log_file}
rm -f ${tempfile}
rm -f ${log_file}
