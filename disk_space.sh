#!/bin/bash

# ScriptsName: disk_space.sh                                
# ScriptsPath:/etc/zabbix/zabbix_agentd.conf.d/disk_space.sh                
# Purpose: 监控节点各磁盘分区使用情况（在zabbix报警历史记录中查看具体信息）            
# Edition: 1.0                                                  
# CreateDate:2016-05-17 14:31                                   
# Author: Payne Zheng <zzuai520@live.com> 


#定义相关目录文件路径
TMPDIR=/tmp/zabbix/disk_space
test ! -d $TMPDIR && mkdir -p $TMPDIR 
TMPFILE=${TMPDIR}/disk_space.txt

#提取磁盘空间>=80%的分区
/bin/df -h | grep "%" | sed 1d | awk '{print $NF,$(NF-1),"Size:"$(NF-4),"Used:"$(NF-3),"Avail:"$(NF-2)}' | awk '+$2>=80' > $TMPFILE

#输出>=80%的分区（zabbix监控输出字符串长度>2即触发报警）
cat $TMPFILE | column -t
