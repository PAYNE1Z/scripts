#!/bin/bash

# ScriptsName: slice_merger.sh                                          
# ScriptsPath:/github/scripts/slice_merge.sh                           
# Purpose: merge all node upload slice nginxlog to one
# Edition: 1.0                                                       
# CreateDate:2016-12-27 10:28                                        
# Author: Payne Zheng <zzuai520@live.com>

log() {
     logger -t "$1" -p local0.info "$2"
}

dateVal=$1
Time=$2
downlogDir=$3
dateDir=$4

while :
do
    domain=$(awk -F/ '{print $(NF-1)}' <<<$dateDir)
    dstDir="${downlogDir}/$domain/$dateVal"
    test ! -d $dstDir && mkdir -p $dstDir
    dstFile="${dstDir}/${dateVal}${Time}.bz2"
    ls $dateDir/*${Time}.bz2 &>/dev/null
    if [ $? -eq 0 ]; then
        pv $dateDir/*${Time}.bz2 > ${dstFile}
        if [ $? -ne 0 ]; then
            log "SLICE-MERGE:" "$dstFile bz2file merge fialed"
            log "SLICE-MERGE:" "$dstFile redo bz2file"
            rm -f ${dstFile}
            pv $dateDir/*${Time}.bz2 > ${dstFile}
            test $? -eq 0 && log "SLICE-MERGE:" "$dstFile redo successfull"
        fi
    fi
    dateTime=$(date -d "$dateVal $Time 5 minute" "+%Y%m%d%H%M")
    Time=${dateTime:8:4}
    test "$Time" = 0000 && break
done
