#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: update_to_wechat.sh                              #
# ScriptsPath:/github/scripts/update_to_wechat.sh               #
# Purpose: zabbix monitor item status push to Wechat and Email  #
# Edition: 1.0                                                  #
# CreateDate:2016-06-16 13:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

for i in "$@"
do
    echo "----start----"
    echo "$i"
    echo "----end----"
done >> /tmp/wechat.debug

Apicall() {
    local GroupName Msg Apiurl
    GroupName=$1
    Msg=$2
    Apiurl="http://push.plcdn.net:7890/20160128"
    curl -H "To: $GroupName" "$Apiurl" -d "$Msg"

}

idcApi() {
    local ip=$1 content=$2 Time=$3 remark=$4
    curl -d "ip=$ip&c=$content&time=$Time&remark=$remark" \
    "http://drms.powerleadercdn.com/index.php/api/sendMessApi"
}

flag=$(grep -ow ping_unreachable <<<"$2")
Status=$(awk -F ':' '{print $1}' <<< "$2")
Body1=$(grep -E "^Host:" <<< "$3" | tr 'Host:' 'HOST: ')
Body2=$(grep -E "^Trigger:" <<< "$3" | awk '{$1=""}1')
From="Messages sent from zabbix"
Time=$(date '+%Y-%m-%d %H:%M:%S')
IP=$(grep -E "^IP:" <<<"$3" | awk '{print $NF}')
eventID=$(grep "event ID" <<<"$3" | awk '{print $NF}')

# function server send to IDC wechat
if [ -z $flag ]; then
    test "$Status" = OK && Title="Angel" || Title="Belial"
    #GroupName="PLCDN-STATUS"
    #GroupName="PLCDN-SUPPORT"
    Msg=$(echo -e "$Title\n $Body1\n $Status: $Body2\n TIME: $Time\n ->$From")
    Apicall "PLCDN-SUPPORT" "$Msg"
else
    if [ "$Status" = OK ]; then
        Msg=$(echo -e "\nIP: $IP\n>> NETWORK RECOVERY. \n---------------\n服务器已恢复,感谢您的支持^_^.\n---------------")
    else
        content="请检查贵机房网络状态,如果是服务器宕机了,请帮忙重启该服务器,谢谢."
        Msg=$(echo -e "\nIP: $IP\n>> NETWORK UNREACHABLE.\n---------------\n$content\n---------------")
    fi
    remark="如有疑问请电：18825565567"
    idcApi "$IP" "$Msg" "$Time" "$remark" 2>/dev/null | tee -a /tmp/wechat.debug 
    
fi

# sendmail
#bash /etc/zabbix/zabbix_server.conf.d/sendmail.sh "$1" "$2" "$3"
echo "$3" | mail -s "$2" "$1"

# 80 port is down and 873 port is donw trigger to AutoChangeNodeState
grep -ow "80 port is down" <<<$2
aaa=$?
if [ "$aaa" = "0" -o "$flag" = "ping_unreachable" ]; then
    echo "$aaa $flag" >> /tmp/zabbix_action.log 
    echo -e "$(date '+%Y-%m-%d %H:%M:%S')\n1: $1 \n------------------------ \
    \n2: $2 \n ------------------------------------ \
    \n3: $3\n#####################################################################\n" >> /tmp/zabbix_action.log
    bash /etc/zabbix/zabbix_server.conf.d/changeNodeState.sh "$2" "$3" 
fi


# temple
# $1
# zzuai520@163.com
# $2
# OK/PROBLEM: 江苏吴江-61.155.137.219-下载 ping_unreachable 
# $3
# Trigger: 江苏吴江-61.155.137.219-下载 ping_unreachable
# Trigger status: OK
# Trigger severity: Disaster
# Trigger URL: 
# IP: 61.155.137.219
# Item values:
# 1. ICMP ping (江苏吴江-61.155.137.219-下载:icmpping): Up (1)
# Original event ID: 7492264
set -e
