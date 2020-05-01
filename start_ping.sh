#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-04-14 14:40:07
# Location: Shenzhen
# Desc:     ping one IP
#

checkIP=$1
pks=$2
sorted=$3
test -z "$4" && read ip_list || ip_list=$4

echo "$(date '+%Y%h%m %H%M%S') : $(basename $0) : $@" >> /tmp/debug.log
echo "$ip_list" >> /tmp/debug.log

xargs -I{} -P50 -n1 <<<$ip_list ssh -p9089 root@{} "bash /root/scripts/pingOne.sh $checkIP $pks $sorted"
