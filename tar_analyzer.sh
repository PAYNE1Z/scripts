#!/bin/bash
#
# Author: Joshua Chen <iesugrace@gmail.com>
# Date: 2016-03-29
# Location: Shenzhen
# Desc: 分析流量及其它若幹種信息
#

# log the report state
logReport() {
    local stat=$1 group=$2 api=$3 msg=$4 localLog ts
    msg=$(xargs <<< "$msg")
    localLog="$workingDir/log/sent_messages.log"
    ts=$(date '+%F %T')
    echo "$ts stat=$stat group=$group api=$api msg=$msg" >> "$localLog"
}

report() {
    local groupName apiUrl msg
    if test "$1" = "warn"; then
        groupName="PLCDN-SUPPORT"
    else
        groupName="PLCDN-STATUS"
    fi
    apiUrl="http://push.plcdn.net:7890/20160128"
    msg=$'Log analyzer:\n'
    msg+="$2"$'\n'
    msg+="Time: $(date +'%F %T')"
    wget -q --tries=1 --timeout=30 --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null

    logReport $? "$groupName" "$apiUrl" "$msg"
}

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

# copy config files, create directories
init() {
    mkdir -p $backupLogDir 
    mkdir -p $flowStats
    mkdir -p $localLog
    mkdir -p $configDir
    test ! -d $IPSource && mkdir $IPSource
    cp -f $deviceList $configDir/
    cp -f $siteUidList $configDir/
}

check_analyzer_stat() {
    local code=$1
    if test $code -ne 0; then
        msg=$'analyzer failed\n'
        msg+="ip=$ip"$'\n'
        msg+="code=$code"
        report warn "$msg"
    fi
}

check_reopen_stat() {
    local today=$(date '+%Y%m%d')
    local logfile="/opt/fenxi/nginx_analysis.log.$today"
    local now=$(date +%s)
    local period=300
    text=$(grep 'Init reopen failed' "$logfile")
    if test -n "$text"; then
        timestr=$(awk -F'[.#]' '{print $4}' <<< "$text")
        date=${timestr:0:8}
        hour=${timestr:8:2}
        min=${timestr:10:2}
        sec=${timestr:12:2}
        rtime=$(date +%s -d "$date $hour:$min:$sec")
        if test $((now - rtime)) -lt $period; then
            msg=$'nginx reopen failed\n'
            msg+="ip=$ip"
            report warn "$msg"
        fi
    fi
}

tagTime=$(date +%Y%m%d%H%M)
ip=$(awk -F ' |;' '/bind/{print $2}' /etc/nginx/node.conf)
startTime=$(date +%s)
period=300  # 5 minutes
comp=10   # 誤差補償
siteUidList="/etc/nginx/webconf.d/siteuidlist.txt"
deviceList="/etc/nginx/webconf.d/devicelist.txt"
configDir="/opt/fenxi"
workingDir="/opt/fenxi2"
flowStats="/data/fenxi_file"
IPSource="/data/IPSource"
DASStats="/data/DomainAccessStatusStats"
URLStats="/data/urlstat"
UseAccessNumStats="/data/UseAccessNumStats"
UseAccessSpeedStats="/data/UseAccessSpeedStats"
asstats="/data/asstats"
UrlKey="/data/UrlKey"
backupLogDir="/data/fenxi_back"
localLog="/data/fenxi_log"
uploadLog="/data/fenxi_upload"
analyzer="$workingDir/src/ngnix_analysis_new_open"
uploader="$workingDir/tar_uploader.sh"
appLogDir="$workingDir/log"
devid=$(grep "$ip" "$deviceList" | awk '{print $1}')
mkdir -p "$appLogDir"
ip=$(awk '/^bind/{sub(";", "", $2); print $2}' /etc/nginx/node.conf)

if test ! -f $siteUidList -o ! -f $deviceList; then
    log error "site uid list or device list missing"
    exit
fi

log "analyzer started at $(date -d@$startTime '+%Y-%m-%d %H:%M:%S')"

init
$analyzer       # 分析工作在這一步做
check_analyzer_stat $?
check_reopen_stat

# 将有多个文件的状态文件 urlstat Urlkey UASStat IPsource 进行打包,打包文件为隐蔽文件
log "pack files started at $(date '+%Y-%m-%d %H:%M:%S')"
cd "$URLStats" && tar czf .urlstat.${tagTime}.${devid}.tar.gz * --remove-files
cd "$UrlKey" && tar czf .UrlKey.${tagTime}.${devid}.tar.gz * --remove-files
#cd "$UseAccessSpeedStats" && tar czf .UASStats.${tagTime}.${devid}.tar.gz * --remove-files
log "pack files end at $(date '+%Y-%m-%d %H:%M:%S')"

# 上傳程序在後臺運行，確保下一個5分鐘分析程序能夠按時啓動
# 給上傳程序指定一個最大允許運行時間，預留10秒做計算誤差補償。
now=$(date +%s)
remain=$((period - (now - startTime) - $comp))
if test "$remain" -gt 0; then
    log "uploader started at $(date -d@$now '+%Y-%m-%d %H:%M:%S')"
    $uploader $remain &
fi
