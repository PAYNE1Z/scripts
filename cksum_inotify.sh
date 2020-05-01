#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2018-08-21 17:36:23
# Location: DongGuang
# Desc:     inotify monitor dir files status, if changed then report
#

monitor_dir="$1"
inotify_args='modify,delete,create,attrib,move'
inotify_wait="/usr/bin/inotifywait"

# print help message
echoHelp() {
    echo "Usage: $0 dir"
    exit
}

# report msg
reportMsg() {
    local ck_sta=$1 ck_file=$2
    echo "Waring: [$ck_file] state is [$ck_sta]" >> /tmp/files-monitor.log 
}

# do it
test $# -ne 1 && echoHelp

$inotify_wait -mrq \
--timefmt '%d/%m/%y %H:%M' \
--format '%T %w%f%e' \
-e $inotify_args $monitor_dir | \
while read files 
do
    echo "$files"
    grep -qE "\.swp|\.swx" <<<"$files" && continue
    sta_type=$(grep -oE "MODIFY|DELETE|CREATE|ATTRIB|MOVED_FROM|MOVED_TO" <<<"$files")
    file_name=$(awk '{print $NF}' <<<"$files" | sed -r 's/MODIFY|DELETE|CREATE|ATTRIB|MOVED_FROM|MOVED_TO//')
    echo "$file_name -> $sta_type"
    reportMsg "$sta_type" "$file_name"
done
