#!/bin/bash

# ScriptsName: day_merger.sh                                          
# ScriptsPath:/github/scripts/day_merge.sh                           
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

sliceMerge() {
    local dateVal=$1 Time=$2 dateDir=$3 timeDir
    while :
    do
        domain=$(awk -F/ '{print $i(NF-2)}' <<<$dateDir)
        dstDir="${downlogDir}/$domain/$dateVal"
        test ! -d $dstDir && mkdir -p $dstDir
        dstFile="${dstDir}/${dateVal}${Time}.bz2"
        find $dateDir/ -name "*${Time}.bz2" >$tempFileList
        if test ! -s $tempFileList ; then
            continue
        else
            xargs -i <$tempFileList lbzip2 -dc {}  | lbzip2 > ${dstFile}
            test $? -ne 0 && log "SLICE-MERGE:" "$dstFile bz2file merge fialed"
        fi
        dateTime=$(date -d "$dateVal $Time 5 minute" "+%Y%m%d%H%M")
        Time=${dateTime:8:4}
        test "$Time" = 0000 && break
    done
}

dayMerge() {
    local dateVal=$1 Time=$2 dir=$3
    cd $dir 
    touch ${dateVal}
    while :
    do
        bz2file="${dateVal}${Time}.bz2"
        if [ -f $bz2file ]; then
            bzcat $bz2file >> ${dateVal}
            rm -f $bz2file
        fi
        echo "$(wc -c ${dateVal} | awk '{print $1}')" >> ${dateVal}.idx
        dateTime=$(date -d "$dateVal $Time 5 minute" "+%Y%m%d%H%M")
        Time=${dateTime:8:4}
        test "$Time" = 0000 && break
    done
    time lbzip2 ${dateVal}
    test $? -ne 0 && log "DAY-MERGE:" "$dateVal lbzip2 fialed"
}

findDir() {
    local srcDir=$1 tempDirList=$2
    find $srcDir -maxdepth 2 -name $dateVal -type d > $tempDirList
}

# find appoint date dir
# /data/cdn_access_statistics/access_log/compressed/723/20160516
#dateVal=20161208
dateVal=$(date "+%Y%m%d" -d -1day)
Time=0000
tempDirList=$(mktemp /tmp/tmp_dir.XXXXX)
tempFileList=$(mktemp /tmp/tmp_file.XXXXX)
logDir=/data/cdn_access_statistics/access_log/new_collecting
downlogDir=/data/vhosts/speedtopcdn.com/web/downlog
export -f sliceMerge
export -f dayMerge

log "SLICE-MERGE:" "start merger..."
findDir "$logDir" "$tempDirList"
xargs -P10 -L1 <$tempDirList bash -c "sliceMerge $dateVal $Time"
wait
log "SLICE-MERGE:" "merger end"

log "DAY-MERGE:" "start merger..."
findDir "$downlogDir" "$tempDirList"
xargs -P10 -L1 <$tempDirList bash -c "dayMerge $dateVal $Time"
log "DAY-MERGE:" "merger end"

trap cleanUp exit
