#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-08-18 17:25:41
# Location: Shenzhen
# Desc:     push node accesslog to logserver2
#

# varaible
workingDir=$(cd $(dirname $0); pwd -P)
dateDay=$(date +%Y%m%d)
dateTime=$(date +%H)
dirList=$(mktemp)

# clean tempfile
cleanUp() {
    rm -f $dirList
}

# make push dir list
makeDirList() {
    logDir="$workingDir/complog"
    find $logDir -maxdepth 2 -name "$dateDay" -type d | sort -nr > $dirList
}

# rsync cmd
rsyncCmd() {
    local dstDir=$1
    rsync -aq --contimeout=60 --timeout=30 \
    --bwlimit=240 --partial --password-file=$passfile \
    $srcDir/ $user@$logserver::$sharName/$dstDir/
}

# rsync push file
pushFile() {
    local user=root passfile=/etc/rsyncd.passwd 
    local sharName=accesslog logserver=183.131.64.126
    while read srcDir
    do
        domainId=$(awk -F/ '{print $(NF-1)}' <<<$srcDir)
        rsyncCmd "$domainId/$dateDay"
        if test $dateTime = 00 -o $dateTime = 01; then
            yesterDay=$(date '+%Y%m%d' -d -1day)
            srcDir=$(awk -vd=$yesterDay -F/ '{$NF=d}1' OFS=/ <<<$srcDir)
            rsyncCmd "$domainId/$yesterDay"
        fi
    done < $dirList
}   

makeDirList
pushFile

trap cleanUp exit
