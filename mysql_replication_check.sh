#!/bin/bash
#
# Author: Payne Zheng <zzuai520@live.com>
# Date: 2017-04-22
# Location: Shenzhen
# Desc: Check the slave status of the MySQL server
#
# Check the replication threads and the time difference
# between the slave and the master, return code meaning
# 0: thread dead
# 1: thread ok, time diff too great
# 2: thread ok, time diff ok
#
exit
threadOk() {
    count=$(grep -Ec 'Slave_IO_Running: Yes|Slave_SQL_Running: Yes' <<< "$1")
    test "$count" -eq 2
}

timeDiff() {
    diff=$(awk -F ": " '/Seconds_Behind_Master/ {print $2}' <<< "$1")
    echo "$diff"
}

user='zabbix'
pass='zabbix'
maxTimeDiff=60
bothOk=2
threadOk=1
threadDead=0
mysql=/usr/local/mysql/bin/mysql

if test ! -x "$mysql"; then
    echo "mysql client is not executable or not exists" >&2
    exit 1
fi

text=$($mysql -u$user -p"$pass" -e "show slave status\G")
if threadOk "$text"; then
    timeDiff=$(timeDiff "$text")
    if test "$timeDiff" -lt "$maxTimeDiff"; then
        echo $bothOk
    else
        echo $threadOk
    fi
else
    echo $threadDead
fi
