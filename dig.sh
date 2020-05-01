#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-07-19 11:53:53
# Location: Shenzhen
# Desc:     check cnmae on nameserver reslove 
#

cleanUp() {
	rm -f $tempfile
}
	
report() {
    local groupName apiUrl msg
    groupName="PLCDN-SUPPORT"
    #groupName="PLCDN-STATUS"
    apiUrl="http://push.plcdn.net:7890/20160128"
    msg=$1
    #groupName=$2
    wget -q --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null
}

checkRes() {
	local resfile=$1 ns=$2	
	sta=$(awk '/status/{print $(NF-2)}' $resfile | tr -d ',')
    res=$(awk '/IN/{print}' $resfile | tail -1)	
	nsip=$(awk '/SERVER:/{print $3}' $resfile | sed -r 's/\(.*\)//')
	if test ! -z "$sta" -a "$sta" != 'NOERROR'; then
		echo "@$ns ==> $dom ==> $sta" | tee -a $notOk
		return 1
	fi
}

runDig() {
	local cname_dom=$1
	for i in {1..8}
	do
		nameServer=ns${i}.speedtopcdn.com
		/usr/bin/dig @$nameServer $cname_dom | grep -E "IN|HEADER|SERVER" &> $tempfile 
		checkRes $tempfile $nameServer
    	if test $? -ne 0; then
    		makeMsg
    		report "$Msg"
    	fi
	done
}

makeMsg() {
Msg=$(echo -e "\
NS-SERVER RESOLVE ERROR\n\
----------------------\n\
NS: $nameServer\n\
NSIP: $nsip\n\
CNAME: $dom\n\
Details:\n ###\
$(cat $tempfile) ###\n\
--------------------\n\
Time: $(date '+%Y-%m-%d %H:%M:%S')")
}

tempfile=$(mktemp)
cname_list=
notOk=/tmp/dns_check/notok.log
errLog=/tmp/dns_check/err.log
test -d /tmp/dns_check || mkdir /tmp/dns_check

getCnameList
while read dom
do 
	runDig $dom
done < $cname_list

trap cleanUp exit
