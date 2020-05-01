#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2016-12-08 05:27:39
# Location: Shenzhen
# Desc:     clean system old files and empty dir
#

log() {
    logger -t "CLEANUP" -p local0.info "$*"
}

# delete original split log dir
# empty directory for all 
log "clean /data/fenxi_log/ old files and empty dir"
find /data/fenxi_log/ -maxdepth 3 -empty | xargs -P10 -L10 rm -rf
log "clean done..."

# delete compressed segment log
# Empty directory and file for 92 days ago (three months)
# empty directory for all
log "clean /data/old_as/compressed_log/ old files and empty dir"
find /data/old_as/complog/ -maxdepth 3 -mtime +30 -type f | xargs -P10 -L10 rm -f
find /data/old_as/complog/ -maxdepth 3 -empty | xargs -P10 -L10 rm -rf
log "clean done..."

# delete refresh debuglog
find /tmp/ -name '[0-9]*_debug.log' -mtime +2 -type f | xargs rm -f

# delete distribtion log
find /tmp/distribute/ -mtime +10 -type f | xargs -L1 rm -f 


# delete analysis result backup log
# for 61 days ago (two months)
#log "clean /data/fenxi_back/ old files"
#find /data/fenxi_back/ -mtime +61 -name ".*" -type f | xargs -P20 -L10 rm -f
#find /data/fenxi_back/ -mtime +61 -type f | xargs -P20 -L10 rm -f
#log "clean done..."

# delete UseAccessSpeedStats analysis result log
# for 30 days ago (one months)
#log "clean /data/UseAccessSpeedStats/ old files"
#find /data/UseAccessSpeedStats/ -mtime +30 | xargs -P10 -L10 rm -f
#log "clean done..."

