#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: update_to_wechat.sh                              #
# ScriptsPath:/github/scripts/update_to_wechat.sh               #
# Purpose: zabbix monitor item status push to Wechat            #
# Edition: 1.0                                                  #
# CreateDate:2016-06-16 13:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

Apicall() {
    local GroupName Msg Apiurl
    GroupName=$1
    Msg=$2
    Apiurl="http://push.plcdn.net:7890/20160128"
    curl -H "To:$GroupName" "$Apiurl" -d "$Msg"
}

Status=$(awk '/^Trigger status:/{print $NF}' <<< "$3")
Body1=$(awk '/^Trigger:/{print $2}' <<< "$3")
Body2=$(awk '/^Trigger:/{print $NF}' <<< "$3")
if [ "$Status" = OK ]; then
    Title="Angel"
else
    Title="Belial"
fi
Msg=$(echo -e "ZABBIX:\n $Title\n $Body1\n $Body2\n $Time")
Time=$(date "+%Y-%H-%d %M:%m:%S")

Apicall PLCDN-SUPPORT "$Msg"

# $2 --> OK/PROBLEM: 江苏吴江-61.155.137.219-下载 ping_unreachable 

# $3
# Trigger: 江苏吴江-61.155.137.219-下载 ping_unreachable
# Trigger status: OK
# Trigger severity: Disaster
# Trigger URL: 
# IP: 61.155.137.219
# Item values:
# 1. ICMP ping (江苏吴江-61.155.137.219-下载:icmpping): Up (1)
# Original event ID: 7492264
