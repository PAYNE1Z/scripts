#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-12-12 14:36:23
# Location: DongGuang
# Desc:     watch rsync_notify.sh is run
#

watch_obj="rsync_notify.sh"
obj_path="/root/scripts/rsync_inotify/rsync_notify.sh"

ps -ef | grep "$watch_obj" | grep -v grep &>/dev/null

if [ $? -eq 0 ];then
    exit
else
    nohup bash $obj_path &
fi
