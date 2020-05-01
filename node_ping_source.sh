#!/bin/bash

# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2016-06-28 16:45:41
# Location: Shenzhen
# Desc: CDN node to source site network connectivity test

pingSource() {
    local node sourceIp cmd action
    node=$1
    sourceIp=$2
    cmd="ssh -p9089 -o StrictHostKeyChecking=no root@$node"
    action="ping -c 10 $sourceIp"
    $cmd $action
}

pingLogDir="/tmp/node_ping_source"
test ! -d "$pingLogDir" && mkdir "$pingLogDir"
pingLogFile=$pingLogDir/ping-$(date '+%Y%m%d%H%M%S').log
sourceIpFile=$(mktemp)

while read sip
do
    if [ ! -z $sip ]; then
        echo $sip >> "$sourceIpFile"
    else
        break
    fi
done < "$1"

while read nip
do
    test -z "$nip" && continue
    grep -qw "$nip" "$sourceIpFile" && continue
    while read sip
        do
            msg=$(pingSource "$nip" "$sip" | grep -E "packet loss|min/avg/max/mdev" | tr "\n" " ")
            echo "$msg"

            logMsg=$(echo "$msg" | awk -F " |/" '{print $6,$(NF-2),$(NF-4),$(NF-3)}' | sed -r 's/\s/,/g')
            echo "$nip,$sip,$logMsg" >> "$pingLogFile"
        done < "$sourceIpFile"
done < "$1"

cat "$pingLogFile"
rm -f "$sourceIpFile"

# The output format is as follows
# nip/183.131.82.249,sip/59.173.16.52,PACKET-LOSS:0%,MAX:10.714ms,MIN:10.631ms,AVG:10.688ms
