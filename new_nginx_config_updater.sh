#!/bin/bash
#
# Author: Joshua Chen <iesugrace@gmail.com>
# Date: 2016-03-10
# Location: Shenzhen
# Desc: update cache server config
#

# Source function library.
. /etc/rc.d/init.d/functions

if [ -f /etc/sysconfig/nginx ]; then
    . /etc/sysconfig/nginx
fi

log() {
    local tag="CDN-CONFIG-UPDATE"
    local pri=local0.info
    logger -t "$tag" -p "$pri" "$*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

report() {
    local groupName apiUrl msg
    #groupName="PLCDN-SUPPORT"
    #groupName="PLCDN-STATUS"
    apiUrl="http://push.plcdn.net:7890/20160128"
    msg=$1
    groupName=$2
    wget -q --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null
}

# Check if it's necessary to update
# It needs to update only when the md5 sum of
# the local profile and the remote profile differ.
needUpdate() {
    local url="http://${mhost}/index.php/portal/profiles_sync?ip=$self"
    localMd5=NULL remoteMd5=
    remoteMd5=$(curl -s --connect-timeout 30 -m 30 "$url" 2>/dev/null)
    test ${#remoteMd5} -ne 32 && log "bad md5 sum of the remote profile" && exit 1
    test -f "$zprofiles" && localMd5=$(md5sum $zprofiles | awk '{print $1}')
    test "$remoteMd5" != "$localMd5"
}

fetchConfig() {
    local tmout=30
    local url="http://${mhost}/profiles/$self/profiles.zip"
    test -f "$zprofiles" && mv $zprofiles $backupZprofiles
    wget -q -T $tmout -O "$zprofiles" "$url"
    cd $tmpConfigDir
    unzip -qq $zprofiles
}

# Backup all files but those
# in the list of specialFiles.
backupConfig() {
    rm -rf $backupConfigDir && \
    mkdir $backupConfigDir && \
    cp -r $targetConfigDir/* $backupConfigDir/ && \
    cd $backupConfigDir && rm $specialFiles
}

# Remove the names in specialFiles from
# stdin, write the result to stdout.
excludeSpecialFiles() {
    local text
    text=$(cat)
    for name in $specialFiles
    do
        text=$(sed -r "/^${name}$/d" <<< "$text")
    done
    echo "$text"
}

# Remove all files except those listed in
# specialFiles, from the target config dir.
cleanTargetConfigDir() {
    cd $targetConfigDir
    ls | excludeSpecialFiles | xargs rm -rf
}

# check errorlog if error type is sourcesite not ok 
# then call source_site_check.sh
checkError() {
    local logFile=$1
    if grep -q 'host not found in upstream' $logFile; then
        bash /root/scripts/source_site_check.sh &>/dev/null
        $nginx -t &> $checkSyntaxLog
        ret=$?
        return $ret
    else
        return 1
    fi
}

# Move all but those in the specialFiles
# to the target config dir, then check.
checkSyntax() {
    cleanTargetConfigDir
    cd $tmpConfigDir
    ls | excludeSpecialFiles | xargs -I{} mv {} $targetConfigDir
    mv /etc/nginx/nginx.conf $backupConfigDir && mv $targetConfigDir/nginx.conf /etc/nginx/
    $nginx -t &> $checkSyntaxLog
    if test $? -ne 0; then
        checkError $checkSyntaxLog
    else
        return 0
    fi
}

# Since all config files that used by the cache
# server are moved to the target location in
# the syntax checking step, here to move only
# the files that are listed in specialFiles.
# mv command is used intentionally for atomicity.
updateConfig() {
    cd $tmpConfigDir
    mv $specialFiles $targetConfigDir/
}

applyConfig() {
    /sbin/service nginx reload &> /dev/null
}

# move all data from the backup dir back to the
# target config dir, remove the downloaded file.
rollback() {
    cleanTargetConfigDir
    mv $backupConfigDir/* $targetConfigDir/ && mv -f $targetConfigDir/nginx.conf /etc/nginx/
    test -s $backupZprofiles && mv $backupZprofiles $zprofiles
}

# Check if the cache server is running
serverAlive() {
    status -p $pidfile -l $lockfile $nginx &> /dev/null
}

feedback() {
    local url time
    time=$(date +%Y%m%d%H%M%S)
    url="http://${mhost}/index.php/portal/device_feedback?ip=$self&version=$pversion&sync_time=$time"
    if [ "$1" = good ]; then
        url+="&status=2&message="
    else
        url+="&status=4&message=="
    fi
    curl -s --connect-timeout 30 -m 30 "$url" &> /dev/null
}

cleanup() {
    rm -rf $tmpConfigDir
    rm -f $backupZprofiles
}

nodeconf=/etc/nginx/node.conf
zprofiles=/var/log/nginx/profiles.zip
backupZprofiles=$(mktemp)
backupConfigDir="/var/log/nginx/webconf.d_bak"
targetConfigDir="/etc/nginx/webconf.d"
tmpConfigDir=$(mktemp -d)
checkSyntaxLog=$(mktemp)
nginx=${NGINX-/usr/sbin/nginx}
lockfile=${LOCKFILE-nginx}
pidfile=${PIDFILE-/var/run/nginx.pid}
specialFiles="devicelist.txt sitelist.txt"
pversion=$(/usr/sbin/nginx -v 2>&1 | awk '{print $NF}')
self=
mhost=

trap cleanup exit

if ! serverAlive; then
    log "cache server is dead"
    exit 1
fi

# Get the local IP address, and the server address
if [ -f "$nodeconf" ]; then
    self=$(awk -F '[ ;]+' '/^\s*bind/ {print $2}' $nodeconf)
    mhost=$(awk -F '[ ;]+' '/^\s*mhost/ {print $2}' $nodeconf)
fi
test -z "$self"  && log "missing value of 'bind' in $nodeconf"  && exit 1
test -z "$mhost" && log "missing value of 'mhost' in $nodeconf" && exit 1

if ! needUpdate; then
    log "no change, nothing to do"
    exit 0
fi

if ! fetchConfig; then
    rm -rf $zprofiles
    log "failed to fetch config"
    exit 1
fi

if ! backupConfig; then
    log "failed to backup config"
    exit 1
fi

if checkSyntax; then
    updateConfig
    applyConfig
    log "config updated: $localMd5 => $remoteMd5"
    feedback good
else
    rollback
    log "syntax check failed, config is rolled back"
    msg=$(echo -e ">CheckSyntax failed:\nNode: $self\n-------------------------\n$(cat $checkSyntaxLog)\n-------------------------\nTime: $(date '+%Y-%m-%d %H:%M:%S')")
    report "$msg" "PLCDN-SUPPORT"
    feedback notgood
fi
