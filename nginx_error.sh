#!/bin/bash
cat /dev/null > /etc/zabbix/zabbix_agentd.conf.d/log.txt
a=`du -b /var/log/nginx/error.log | awk '{print $1}'`
c=`cat /etc/zabbix/zabbix_agentd.conf.d/tmp`
b=`echo "$a-$c" | bc`
tail -c $b /var/log/nginx/error.log | grep -vE "referrer|favicon.ico|while resolving|signal process started|static.99elon.com|zc.qq.com|www.baidu.com|\(2: No such file or directory\)|Connection reset by peer"|awk '{$3=$4=$5=""}1'|awk -F "," '{$2=""}1' | uniq > /etc/zabbix/zabbix_agentd.conf.d/tmp1.txt
grep "Connection timed out" /etc/zabbix/zabbix_agentd.conf.d/tmp1.txt > /etc/zabbix/zabbix_agentd.conf.d/tmp2.txt
cat /etc/zabbix/zabbix_agentd.conf.d/tmp2.txt | while read line 
do
	domain=`echo $line | sed -r 's/.*host: "([^"]*)".*/\1/'`
	time=`echo $line | awk '{print $1" "$2}'`
	a=`grep $domain /etc/zabbix/zabbix_agentd.conf.d/time_domain.txt`
	if [ -z "$a" ]
	then
		echo "$time $domain" >> /etc/zabbix/zabbix_agentd.conf.d/time_domain.txt
	else
		clock=`date -d "$time" +%s`
		lasttime=`grep $domain /etc/zabbix/zabbix_agentd.conf.d/time_domain.txt | awk '{print $1" "$2}'`
		lastclock=`date -d "$lasttime" +%s`
		difftime=`echo "$clock-$lastclock" | bc`
		b=`echo "$time $domain"`
		if [ "$difftime" -le 600 ]
		then
			echo $line >> /etc/zabbix/zabbix_agentd.conf.d/log.txt
			sed -i "s@$a@$b@g" /etc/zabbix/zabbix_agentd.conf.d/time_domain.txt
		else
			sed -i "s@$a@$b@g" /etc/zabbix/zabbix_agentd.conf.d/time_domain.txt
		fi
	fi
done
grep -v "Connection timed out" /etc/zabbix/zabbix_agentd.conf.d/tmp1.txt >> /etc/zabbix/zabbix_agentd.conf.d/log.txt
cat /etc/zabbix/zabbix_agentd.conf.d/log.txt
echo $a > /etc/zabbix/zabbix_agentd.conf.d/tmp
