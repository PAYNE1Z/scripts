#!/bin/bash

# ScriptsName: day_merger.sh                                          
# ScriptsPath:/github/scripts/day_merge.sh                           
# Purpose: merge slice nginxlog to one day
# Edition: 1.0                                                       
# CreateDate:2016-12-27 10:28                                        
# Author: Payne Zheng <zzuai520@live.com>

log() {
     logger -t "$1" -p local0.info "$2"
}

dateVal=$1
Time=$2
dir=$3
domainID=$(awk -F/ '{print $(NF-1)}' <<<$dir)

cd $dir 
touch ${dateVal}.bz2
mkdir -p /dev/shm/$dateVal/$domainID
log "DAY-MERGE:" "start domainID:$domainID"
while :
do
    bz2file="${dateVal}${Time}.bz2"
    if [ -f $bz2file ]; then
        pv $bz2file >> ${dateVal}.bz2
        test $? -eq 0 && mv $bz2file /dev/shm/$dateVal/$domainID/ || log "DAY-MERGE:" "$bz2file fialed"
        #test $? -eq 0 && rm -f $bz2file || log "DAY-MERGE:" "$bz2file fialed"
    fi  
    echo "$(wc -c ${dateVal}.bz2 | awk '{print $1}')" >> ${dateVal}.idx
    dateTime=$(date -d "$dateVal $Time 5 minute" "+%Y%m%d%H%M")
    Time=${dateTime:8:4}
    test "$Time" = 0000 && { log "DAY-MERGE:" "domainID:$domainID end"; break; }
done

rm -rf /dev/shm/$dateVal/$domainID
#time lbzip2 ${dateVal}
test $? -ne 0 && log "DAY-MERGE:" "$dateVal lbzip2 fialed"
