#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-07-19 11:53:53
# Location: Shenzhen
# Desc:     check cnmae on nameserver reslove 
#

cleanUp() {
	rm -f $tempfile $resFile
}
	
digInfo() {
    status=$(awk -F ' |,' '/QUERY, status/{print $(NF-3)}' $tempFile)
    nsServer=$(awk '/SERVER:/{print $NF}' $tempFile)
    answerSection=$(awk '/IN.*A/{if($5 != "")print $5}' $tempFile | xargs)
}

makeReturn() {
    msg="CNAME: $cname_dom\n"
    msg+="STATUS: $status\n"
    msg+="RESULT: $answerSection\n"
    msg+="NS: $nameServer\n"
    msg+="NSIP: $nsServer"
    #msg+="DETAILS: $(cat $tempfile)"$'\n'
}

runDig() {
	local cname_dom=$1
	for i in {1..8}
	do
		nameServer=ns${i}.speedtopcdn.com
		/usr/bin/dig @$nameServer $cname_dom >$tempFile
        digInfo
        makeReturn
        echo -e "$msg" >> $resFile
	done
}

runOneDig() {
    local cname_dom=$1 nameServer=$2
    /usr/bin/dig @$nameServer $cname_dom >$tempFile
    digInfo
    makeReturn
    echo -e "$msg" >> $resFile
}


tempFile=$(mktemp)
resFile=$(mktemp)
cname=$1
nsServer=$2

test $# -ne 2 && \
{ echo -e "ERROR: Parameter missing\nUsage: $0 CNAME [nameserver|all]"; exit; }

echo "$(awk '/bind/{print $NF}' /etc/nginx/node.conf | tr -d ';')" > $resFile

if test "$2" = "all"; then 
    runDig "$cname"
else
    runOneDig "$cname" "$nsServer"
fi

echo "----------" >> $resFile

cat $resFile

trap cleanUp exit

# dig return message
#  ; <<>> DiG 9.9.4-RedHat-9.9.4-38.el7_3.3 <<>> @ns8.speedtopcdn.com www.zqgame.com.speedtopcdn.com
#  ; (1 server found)
#  ;; global options: +cmd
#  ;; Got answer:
#  ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 4934
#  ;; flags: qr aa rd; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1
#  ;; WARNING: recursion requested but not available
#  
#  ;; OPT PSEUDOSECTION:
#  ; EDNS: version: 0, flags:; udp: 4096
#  ;; QUESTION SECTION:
#  ;www.zqgame.com.speedtopcdn.com.        IN      A
#  
#  ;; ANSWER SECTION:
#  www.zqgame.com.speedtopcdn.com. 600 IN  A       121.32.230.8
#  www.zqgame.com.speedtopcdn.com. 600 IN  A       14.152.50.42
#  
#  ;; Query time: 40 msec
#  ;; SERVER: 125.208.27.113#53(125.208.27.113)
#  ;; WHEN: Mon Sep 04 10:25:02 CST 2017
#  ;; MSG SIZE  rcvd: 91
