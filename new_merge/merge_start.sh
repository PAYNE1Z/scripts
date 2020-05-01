#!/bin/bash

# ScriptsName: merge_start.sh                                          
# ScriptsPath:/github/scripts/start_merge.sh                           
# Purpose: merge all node upload slice nginxlog to one
#            merge slice nginxlog to one day
# Edition: 1.0                                                       
# CreateDate:2016-12-27 10:28                                        
# Author: Payne Zheng <zzuai520@live.com>

log() {
     logger -t "$1" -p local0.info "$2"
}

cleanUp() {
    rm -f $tempDirList
    rm -f $tempFileList
}

findDir() {
    local srcDir=$1 tempDirList=$2
    log "LOG-MERGE:" "start findDir..."
    find $srcDir -maxdepth 2 -name $dateVal -type d | sort -t '/' -k6,6nr > $tempDirList
    log "LOG-MERGE:" "findDir end"
}

# find appoint date dir
# /data/cdn_access_statistics/access_log/compressed/723/20160516
dateVal=$(date "+%Y%m%d" -d -1day)
Time=0000
tempDirList=$(mktemp /tmp/tmp_dir.XXXXX)
logDir=/data/cdn_access_statistics/access_log/new_collecting
downlogDir=/data/vhosts/speedtopcdn.com/web/downlog
mergeWork=/data/cdn_access_statistics/program/new_merge/merge_working.sh

log "LOG-MERGE:" "start merger..."
findDir "$logDir" "$tempDirList"
xargs -P10 -L1 <$tempDirList bash $mergeWork "$dateVal" "$Time" "$downlogDir"
log "LOG-MERGE:" "merger end"


trap cleanUp exit
