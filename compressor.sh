#!/bin/bash
#
# Author: Joshua Chen <iesugrace@gmail.com>
# Date: 2016-05-12
# Location: Shenzhen
# Desc: temporary script for log compressing
#

uncompressed_log=/data/fenxi_log
compressed_log=/data/old_as/complog

# deal with log files created in or later than May 2016,
# and before the start of 'today'
sleep 60
startTime="2016-04-30 23:59:59"
endTime=$(date '+%Y-%m-%d %H:%M:%S')
word=$(date '+%Y%m%d' -d -1day)
deviceIP=$(awk -F ' |;' '/bind/{print $2}' /etc/nginx/node.conf)
deviceID=$(awk "/$deviceIP/{print \$1}" /etc/nginx/webconf.d/devicelist.txt)
test -z $deviceID && deviceID=$deviceIP

#find $uncompressed_log/ -name "$word*" -type f | \
find $uncompressed_log/ -newerct "$startTime" ! -newerct "$endTime" -type f | \
while read path
do
    if test "${path%.bz2}" = "$path"; then
        lbzip2 $path
        bzfile="${path}.bz2"
    else
        bzfile=$path
    fi
    bzfileName=${bzfile##*/}
    Time=${bzfileName:0-8:4}
    read domain_id date <<< "$(awk -F/ '{print $(NF-2),$(NF-1)}' <<< "$path")"
    dstDir="$compressed_log/$domain_id/$date"
    mkdir -p "$dstDir"
    mv "$bzfile" "$dstDir/${deviceID}.${bzfileName}"
done
