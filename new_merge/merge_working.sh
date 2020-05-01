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
domainID=$(awk -F/ '{print $(NF-1)}' <<<$dateDir)

log "LOG-MERGER:" "start slice->day-> $domainID/$dateVal"
while :
do
    downFileDir="$downlogDir/$domainID/$dateVal"
    test ! -d $downFileDir && mkdir -p $downFileDir
    downFile="$downFileDir/${dateVal}.bz2"
    downFileIdx="$downFileDir/${dateVal}.idx"
    test $Time = 0000 && { :>$downFile; :>$downFileIdx; }
    ls $dateDir/*${Time}.bz2 &>/dev/null
    if [ $? -eq 0 ]; then
        pv $dateDir/*${Time}.bz2 >> ${downFile}
        if [ $? -ne 0 ]; then
            log "SLICE-MERGE:" "$domainID$Time bz2file merge fialed"
            log "SLICE-MERGE:" "$domainID$Time redo bz2file"
            pv $dateDir/*${Time}.bz2 >> ${downFile}
            test $? -eq 0 && log "SLICE-MERGE:" "$domainID$Time redo successfull"
        fi
    fi
    echo "$(wc -c ${downFile} | awk '{print $1}')" >> ${downFileIdx}
    dateTime=$(date -d "$dateVal $Time 5 minute" "+%Y%m%d%H%M")
    Time=${dateTime:8:4}
    test "$Time" = 0000 && break
done

log "LOG-MERGER:" "end slice->day-> $domainID/$dateVal"
