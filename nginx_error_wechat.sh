#!/bin/bash

# ScriptsName: nginx_error_wechat.sh                                
# ScriptsPath:/etc/zabbix/zabbix_agentd.conf.d/nginx_error_wechat.sh               
# Purpose: Monitor the analysis of nginx-error log, identify the source of the problem of the domain name 
#          to push the ZABBIX monitoring page and customer WeChat            
# Edition: 1.0                                                  
# CreateDate:2016-05-26 14:31                                   
# Author: Payne Zheng <zzuai520@live.com> 

apicall() {
    local domain occurtime content
    domain=$1
    occurtime=$2
    content=$3
    curl http://drms.powerleadercdn.com/index.php/api/sendAlarmMsg \
        -d "domain=$domain&occurtime=$occurtime&content=$content"
}

localIP=$(/sbin/ifconfig | grep "inet addr" | grep -v 127.0.0.1 | awk '{print $2}' | tr -d "addr:" | head -1)
ngerrorlog=/var/log/nginx/error.log
tmpdir=/etc/zabbix/zabbix_agentd.conf.d/nginxtmp
logfile=$tmpdir/errlog.txt
lastsizefile=$tmpdir/lastsize.txt
pbdomain=$tmpdir/pbdomain.txt
logsize=$(du -b "$ngerrorlog" | awk '{print $1}')
ignoredDom="ff.zqgame.com www.souidc.com www.gozmbh.cn www.jtlhfp.cn www.fa253.com"

test ! -d $tmpdir && mkdir -m 755 $tmpdir
test ! -f $pbdomain && touch $pbdomain
:> ${pbdomain}

if [ -f $lastsizefile ]; then
    read lastsize < $lastsizefile
    diffsize=$((logsize-lastsize))
else 
    lastsize=$logsize
    diffsize=$(($logsize-$lastsize))
fi

test $diffsize -lt 30 && { echo "$logsize" > $lastsizefile ; exit 0; }

tail -c $diffsize $ngerrorlog | grep "Connection timed out" | \
    grep -vE "127.0.0.1|favicon.ico|pak2vii.cn|referrer|183.251.62.179|27.155.94.210|121.32.230.233|121.32.230.227|60.211.204.229|60.211.204.228|183.131.64.69|183.131.64.70|183.232.150.4|183.232.150.5|114.119.10.168|114.119.10.169|123.134.94.38|58.20.31.163|14.152.50.41|113.113.97.227|14.152.50.37|baidu.com" | grep -vE "$ignoredDom" | \
    sed -r 's/(\[error\]+).*(Connection timed out).*(upstream)/\1\ \[\2\] \3/' | \
    sort -k 9 | uniq -f 8 > ${logfile}

while read line 
do
	acctime=$(echo $line | awk '{print $1,$2}')
    domain=$(echo $line | sed -r 's/.*host: "([^"]*)".*/\1/')
	sourceip=$(echo $line | awk -F/ '{print $5}' | awk -F: '{print $1}')
	url=$(echo $line | awk '{gsub("\042|,",""); print $8,$NF}' | awk -F'[/ ]' '{$3=$NF}NF--' OFS=/)
    orgurl=$(echo $line | awk '{print $8}' | tr -d '",')
    port=$(echo $orgurl | grep -oE ":[0-9]{2,5}" | tr -d ':')
    http=${url%%://*}
    tryurl="http://$domain -e http-proxy=$sourceip:80"

	#stat1=$(curl --connect-timeout 10 --retry 3  -o /dev/null -s -w %{http_code} "$url" -x "$sourceip:80")
	#stat0=$(curl --connect-timeout 10 --retry 2  -o /dev/null -s -w %{http_code} "$orgurl")
	stat1=$(curl --connect-timeout 10 --retry 2  -o /dev/null -s -w %{http_code} "$url" -x ${sourceip}:$port)
	stat2=$(curl --connect-timeout 10 --retry 2  -o /dev/null -s -w %{http_code} "$url" -x 127.0.0.1:80)
	#stat1=$(curl --connect-timeout 10 --retry 3  -o /dev/null -s -w %{http_code} http://"$domain" -x "$sourceip:80")
    test $stat1 = 404 -o "$http" = "https" && continue
    test $stat1 = 200 -o $stat2 = 200 && continue
    test $sourceip = 1.1.1.1 && continue
    grep -qw "${domain%:*}" <<<"$ignoredDom" && continue
    test -z "${domain%:*}" -o -z "$sourceip" && continue

    if [ $stat1 = 000 -o $stat1 -gt 400 ]; then
        grep -qw "${domain%:*}" "${pbdomain}" && continue 
        grep -qw "$sourceip" "${pbdomain}" && continue
       	echo -e "$acctime : $domain : $sourceip : $url : $stat1" >> ${pbdomain}
	    #test $stat1 -eq 000 && xxx="No response from the source station" || xxx=$stat1
        content=$(echo -e "SOURCE SITE PROBLEM \nDomain：$domain \nSourceIP：$sourceip \nURL: $url \nReturn：$stat1 \nFrom: $localIP")
       	apicall dltest.borncloud.net "$acctime" "$content"
	else
		continue
	fi
done < ${logfile}

echo "$logsize" > $lastsizefile
#cat ${pbdomain}
