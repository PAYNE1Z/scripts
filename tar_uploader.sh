#!/bin/bash
#
# Author: Joshua Chen <iesugrace@gmail.com>
# Date: 2016-03-29
# Location: Shenzhen
# Desc: 上傳分析的結果
#

# To log an error, the first argument shall be 'error'
log() {
    local file
    if test "$1" = "error"; then
        file="$appLogDir/error.log"
        shift 1
    else
        file="$appLogDir/access.log"
    fi
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    msg="[$timestamp] $*"
    echo "$msg" >> $file
}

# create directories
init() {
    mkdir -p $backupLogDir
    mkdir -p $flowStats
    mkdir -p $localLog
    mkdir -p $appLogDir
}

# push one file to the remote server
pushFile() {
    test $# -ne 2 && { echo "wrong arguments" >&2; return; }
    local file=$1 shareName=$2
    baseName=${file##*/}
    $rsync --contimeout=30 --timeout=30 -az --partial $file $server::$shareName/$baseName
    if test $? -eq 0; then
	tag=${file:0:1}
    awk '{if($4!=0&&$5!=0&&i++%2)$5=$4*$5}{print}' $file 1<> $file
	test "$tag" == "." && mv $file $backupLogDir/${file#*.} || mv $file $backupLogDir
        log "$baseName uploaded"
        return 0
    else
        log "$baseName upload failed"
        return 1
    fi
}

# push all files in the directory to the remote server
# sleep for some time after a push failure.
pushDir() {
    test $# -ne 2 && { echo "wrong arguments" >&2; return; }
    local dir=$1 shareName=$2 file stat=0 sleepTime=2
    while read file
    do
        pushFile $file $shareName || { stat=1; sleep $sleepTime; }
    done < <(find $dir/ -type f)
    return $stat
}

# keep running until the sub-command returns 0.
runUntilSuccess() {
    while true
    do
        "$@" && break
        sleep 3
    done
}

# Run a command for a set time,
# return if the sub command returned,
# or when the time is over.
doForSometime() {
    local period=$1 startTime=$(date +%s) sleepTime=2 now timeDiff
    shift
    runUntilSuccess "$@" &
    pid=$!
    while true
    do
        test ! -d /proc/$pid && break           # process terminated
        now=$(date +%s)
        timeDiff=$((now - startTime))
        if test $timeDiff -gt $period; then     # time is over
            kill -9 $pid
            log "time over for task: $@"
            break
        fi
        sleep $sleepTime
    done
}

uploadFlow() {
    pushDir $flowStats bdrz
}

uploadOthers() {
    # 上傳域名訪問狀態碼的統計結果
    dir=$DASStats
    shareName=DomainAccessStatusStats
    pushDir $dir $shareName

    # 上傳用戶訪問速度的分析結果（IP 前三位）
    shareName=asstats
    dir=$asstats
    pushDir $dir $shareName

    # 上傳用戶訪問次數的統計結果，這數據用於檢查調度情況是否合理
    dir=$UseAccessNumStats
    shareName=UseAccessNumStats
    pushDir $dir $shareName

    # 上傳熱點url 的統計結果
    dir=$URLStats
    shareName=urlstat
    pushDir $dir $shareName

    # 上傳url 與md5 碼的對應關系
    shareName=Urlkey
    dir=$UrlKey
    pushDir $dir $shareName

    # 上傳用戶訪問速度的分析結果（IP 前四位）
    dir=$UseAccessSpeedStats
    shareName=UseAccessSpeedStats
    #pushDir $dir $shareName

    # 上传IP来源
    shareName=ipsource
    dir=$IPSource
    #pushDir $dir $shareName
}

allowedTime=$1
workingDir="/opt/fenxi2"
flowStats="/data/fenxi_file"
DASStats="/data/DomainAccessStatusStats"
URLStats="/data/urlstat"
UseAccessNumStats="/data/UseAccessNumStats"
UseAccessSpeedStats="/data/UseAccessSpeedStats"
asstats="/data/asstats"
IPSource="/data/IPSource"
UrlKey="/data/UrlKey"
backupLogDir="/data/fenxi_back"
localLog="/data/fenxi_log"
uploadLog="/data/fenxi_upload"
rsync="/usr/bin/rsync"
server="43.241.11.42"
appLogDir="$workingDir/log"
TimeTemp=$(mktemp)

init
workTime=$((allowedTime / 2))
if test -z "$workTime" -o "$workTime" -lt 1; then
    log "invalid time: $allowedTime"
    exit 1
fi
{ time -p doForSometime $workTime uploadFlow ; } 2>$TimeTemp
Text=$(awk '/real/{print $2}' $TimeTemp)
FlowTime=${Text%%.*}
OthersTime=$((allowedTime - FlowTime))
doForSometime $OthersTime uploadOthers
now=$(date +%s)
rm -rf $TimeTemp
log "uploader ended at $(date -d@$now '+%Y-%m-%d %H:%M:%S')"
