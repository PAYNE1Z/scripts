#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: mysql_status.sh                                  #
# ScriptsPath:/github/scripts/mysql.status.sh                   #
# Purpose: <zabbix monitor scripts>                             #
#          check MySQL various State value push to zabbix page  #
# Edition: 1.1                                                  #
# CreateDate:2016-06-19 13:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

Variable=$1
MysqlUser=zabbixagent
MysqlPasswd=zabbixagent
MysqlBin="/usr/bin/mysql"

LogInShow() {
    local KeyWord
    KeyWord=$1
    Value=$("$MysqlBin" -u "$MysqlUser" -p"$MysqlPasswd" -e "show status;" | \
    awk '/'$KeyWord'/{print $2}')
    echo $Value
}

case $Variable in
    
    "Threads_running" )
        LogInShow $Variable
        ;;

    "Threads_created" )
        LogInShow $Variable
        ;;

    "Threads_connected" )
        LogInShow $Variable
        ;;

    "Threads_cached" )
        LogInShow $Variable
        ;;

        * )
        exit 0
esac
