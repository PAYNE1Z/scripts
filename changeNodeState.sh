#!/bin/bash
# Author: Joshua Chen
# Date: 2016-01-22
# Location: Shenzhen
# Desc: set the node to be enabled/disabled on condition,
# using the OPS API.



login() {
    resp=$(curl -m $CURL_MXTIME -i --url "$loginUrl" \
           -d "username=$userName&password=$password" -c $cookie 2>/dev/null)
    if test $? -ne 0; then
        return $API_CALL_FAILED
    elif grep -qE 'HTTP.* 200 OK' <<< "$resp"; then
        if grep -qE "$LOGINOKCODE" <<< "$resp"; then
            return $LOGIN_SUCCESS
        else
            return $LOGIN_FAILED
        fi
    else
        return $API_CALL_FAILED
    fi
}

change() {
    local ip stat eventCode eventId
    ip=$1
    stat=$2
    eventCode=$3
    eventId=$4
    resp=$(curl -m $CURL_MXTIME \
           -i --url "$applyUrl/$ip/$stat/$eventCode/$eventId" -b $cookie 2>/dev/null)
    if test $? -ne 0; then
        return $API_CALL_FAILED
    elif grep -qE 'HTTP.* 200 OK' <<< "$resp"; then
        if grep -qE "$APPLYOKCODE" <<< "$resp"; then
            return $CHANGE_APPLIED
        elif grep -qE "$APPLYFAILEDCODE" <<< "$resp"; then
            return $CHANGE_FAILED
        else
            return $CHANGE_IGNORED
        fi
    else
        return $API_CALL_FAILED
    fi
}

# any response determines a success result
pingOne() {
    if ! ping -W1 -c3 $1 | grep -q '100% packet loss'; then
        echo ok
    fi
}

# simultaneously ping
simulPing() {
    while read ip
    do
        pingOne $ip &
    done <<< "$1"
    wait
}

# more or equal to 80% success determines a GOOD stat
weAreGood() {
    url="${refIpUrl}/$1"
    ipList=$(wget -O - $url 2>/dev/null | sed '/^$/d')
    if test -z "$ipList"; then
        msg=$'Auto dispatch aborted.\n'
        msg+="Reason: no reference IPs for $1"$'\n'
        msg+="Task: $task"$'\n'
        msg+="Event: $event"
        log "$msg"
        report warn "$msg"
        exit 1
    fi
    resp=$(simulPing "$ipList")
    listCount=$(echo "$ipList" | wc -l)
    respCount=$(echo "$resp" | wc -l)
    percnt=$(echo "scale=2;${respCount}/${listCount}*100" | bc | awk -F. '{print $1}')
    test "$percnt" -ge 80
}

# whether the IP is in the excluded list or not
isExcluded() {
    grep -q "^$1\$" "$xcldList"
}

getStat() {
    awk '/^Trigger status:/{print $NF}' <<< "$1"
}

getToStat() {
    if test "$1" = PROBLEM; then
        toStat=0
    else
        toStat=1
    fi
    echo $toStat
}

getIp() {
    awk '/^IP:/{print $NF}' <<< "$1"
}

log() {
    logger -t "[AUTODISPATCH]" -p local0.info "$*"
}

# log the report state
logReport() {
    local stat=$1 group=$2 api=$3 msg=$4 wd localLog ts
    msg=$(xargs <<< "$msg")
    wd=$(cd -P $(dirname $0); pwd)
    localLog="$wd/data/sent_messages.log"
    ts=$(date '+%F %T')
    echo "$ts stat=$stat group=$group api=$api msg=$msg" >> "$localLog"
}

report() {
    local groupName apiUrl msg stat
    if test "$1" = "warn"; then
        groupName="PLCDN-SUPPORT"
    else
        groupName="PLCDN-STATUS"
    fi
    apiUrl="http://push.plcdn.net:7890/20160128"
    msg="$2"$'\n'
    msg+="Time: $(date +'%F %T')"
    wget -q --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null

    logReport $? "$groupName" "$apiUrl" "$msg"
}

# parse the input string, produce two
# variables for composing the report message.
parseTask() {
    local subject=$1 ip=$2 toStat=$3
    event=$(awk -F": " '{print $NF}' <<< "$subject")
    if test "$toStat" = 1; then     # to enable
        task="enable $ip"
        event="recover from $event"
    else
        task="disable $ip"
    fi
}

cleanup() {
    rm -f $cookie
}

# generate a unique id for the task
# the id is a 40-char sha1sum.
genEventId() {
    head -c 1024 /dev/urandom | sha1sum | awk '{print $1}'
}

# log the ignored request for later query
# strip off the 'PROBLEM: ' and 'OK: ' characters from
# the subject, acquire a lock to prevent race condition.
logIgnored() {
    local toStat=$1 ip=$2 subject=${3##*: } ts=$(date +%s)
    (
        flock -w $lockTimeOut 3 || return
        echo "$ts,$ip,$toStat,$subject" >> "$igndHist"
    ) 3> $igndHistLock
}

# check if the request was ignored
# within a set period before.
# use index to match the subject rather
# than $3, because subject may contain commas.
# acquire a lock to prevent race condition.
wasIgnored() {
    local stat=$1 ip=$2 subject=${3##*: } period=1800
    (
        flock -w $lockTimeOut 3 || return
        awk -v now=$(date +%s) -v period=$period \
            -v stat=$stat -v ip=$ip -v subject="$subject" \
            -F, 'now - $1 < period && $2 == ip && $3 == stat && index($0, subject) != 0' \
            "$igndHist" | grep -q .
    ) 3> $igndHistLock
}

# delete entries that match the given criteria
# acquire a lock to prevent race condition.
clearIgnored() {
    local stat=$1 ip=$2 subject=${3##*: } tmpfile
    (
        flock -w $lockTimeOut 3 || return
        tmpfile=$(mktemp)
        awk -v stat=$stat -v ip=$ip -v subject="$subject" \
            -F, '$2 != ip || $3 != stat || index($0, subject) == 0' "$igndHist" > $tmpfile
        mv $tmpfile "$igndHist"
    ) 3> $igndHistLock
}

userName='xxxxx'
password='xxxx'
loginUrl='http://drms.xxxxx.com/index.php/admin/login'
applyUrl='http://drms.xxxxxx.com/index.php/portal/dispatchStatus'
refIpUrl='http://drms.xxxxxxxx.com/index.php/portal/getIPs'
xcldList='/etc/zabbix/zabbix_server.conf.d/data/excluded_ip'
igndHist='/etc/zabbix/zabbix_server.conf.d/data/ignored_hist'
igndHistLock='/etc/zabbix/zabbix_server.conf.d/data/ignored_hist_lock'
lockTimeOut=5

cookie=$(mktemp -u)
LOGINOKCODE=v00006
APPLYOKCODE=v30007
APPLYFAILEDCODE=030008
CURL_MXTIME=60
CURL_RETRY_DELAY=3

# return codes
API_CALL_FAILED=11
LOGIN_SUCCESS=12
LOGIN_FAILED=13
CHANGE_APPLIED=14
CHANGE_FAILED=15
CHANGE_IGNORED=16

# event definition
port80DownStr='80 port is down'
pingUnreachableStr='ping_unreachable'
port80DownCode=1
pingUnreachableCode=2

# 给username, password, loginUrl, applyUrl,
# refIpUrl, xcldList, igndHist 赋上适当的值之后，
# 把CONFIGOK 设置为1即可。
CONFIGOK=1

trap cleanup exit

# start to work
log "start to work"
subject=$1
message=$2
stat=$(getStat "$message")
toStat=$(getToStat "$stat")
ip=$(getIp "$message")
parseTask "$subject" "$ip" "$toStat"    # produce two variables: task, event

if test "$CONFIGOK" -ne 1; then
    log "config error: variable username, password, loginUrl, applyUrl shall be set"
    errmsg=$'Auto dispatch aborted.\n'
    errmsg+=$'Reason: config error\n'
    errmsg+="Task: $task"$'\n'
    errmsg+="Event: $event"
    report warn "$errmsg"
    exit 1
fi

# the igndHist must be set and the file can be created
(
    flock -w $lockTimeOut 3 || exit 1
    if test -z "$igndHist" || ! touch "$igndHist"; then
        log "ignored history file not set or can not be created/changed"
        errmsg="Auto dispatch aborted."$'\n'
        errmsg+="Reason: runtime error"$'\n'
        errmsg+="Task: $task"$'\n'
        errmsg+="Event: $event"
        report warn "$errmsg"
        exit 1
    else
        exit 0
    fi
) 3> $igndHistLock
test $? -ne 0 && exit 1

# exclude the ip in the excluded list
if test -z "$xcldList" -o ! -f "$xcldList"; then
    log "excluded list not set or the file not exists"
    errmsg="Auto dispatch aborted."$'\n'
    errmsg+="Reason: runtime error"$'\n'
    errmsg+="Task: $task"$'\n'
    errmsg+="Event: $event"
    report warn "$errmsg"
    exit 1
fi
if isExcluded "$ip"; then
    msg="$ip is in the excluded list"
    log "$msg"
    # 2016-05-23 12:47, temporarily disable this report
    #errmsg="Auto dispatch aborted."$'\n'
    #errmsg+="Reason: $msg"$'\n'
    #errmsg+="Task: $task"$'\n'
    #errmsg+="Event: $event"
    #report warn "$errmsg"
    exit 1
fi

# filter events
if grep -q "$port80DownStr" <<< "$subject"; then
    code=$port80DownCode
elif grep -q "$pingUnreachableStr" <<< "$subject"; then
    code=$pingUnreachableCode
else
    msg="unrecognized event ($subject)"
    log "$msg"
    errmsg="Auto dispatch aborted."$'\n'
    errmsg+="Reason: $msg"$'\n'
    errmsg+="Task: $task"$'\n'
    errmsg+="Event: $event"
    report warn "$errmsg"
    exit 1
fi

# do a sanity check before sending command
if test "$toStat" = 0 && ! weAreGood $ip; then
    msg="sanity check failed"
    log "$msg"
    errmsg="Auto dispatch aborted."$'\n'
    errmsg+="Reason: $msg"$'\n'
    errmsg+="Task: $task"$'\n'
    errmsg+="Event: $event"
    report warn "$errmsg"
    exit 1
fi

# login
while true
do
    login
    x=$?
    if test "$x" = "$LOGIN_FAILED"; then
        log "login failed"
        msg="Task: $task"$'\n'
        msg+="Event: $event"$'\n'
        msg+="Result: login failed"
        report warn "$msg"
        exit 1
    elif test "$x" = "$API_CALL_FAILED"; then
        errmsg="Failed to call API for login"
        log "$errmsg"
        msg="Task: $task"$'\n'
        msg+="Event: $event"$'\n'
        msg+="Result: $errmsg (retrying)"
        report warn "$msg"
        sleep $CURL_RETRY_DELAY
        continue    # keep trying when call to api failed
    fi
    break
done

eventId=$(genEventId)

# apply change
while true
do
    change "$ip" "$toStat" "$code" "$eventId"
    x=$?
    if test "$x" = "$CHANGE_APPLIED"; then      # the node disabled/enabled, shall warn
        log "changed successfully ($subject)"
        msg="Task: $task"$'\n'
        msg+="Event: $event"$'\n'
        msg+="Result: success"
        if test "$toStat" = 1 && wasIgnored 0 "$ip" "$subject"; then
            clearIgnored 0 "$ip" "$subject"
            report message "$msg (disable request ignored)"
        else
            report warn "$msg"
        fi
    elif test "$x" = "$CHANGE_FAILED"; then      # API internal error, shall warn
        log "change failed ($subject)"
        msg="Task: $task"$'\n'
        msg+="Event: $event"$'\n'
        msg+="Result: failed"
        report warn "$msg"
    elif test "$x" = "$API_CALL_FAILED"; then
        errmsg="Failed to call API for change"
        log "$errmsg"
        msg="Task: $task"$'\n'
        msg+="Event: $event"$'\n'
        msg+="Result: $errmsg (retrying)"
        report warn "$msg"
        sleep $CURL_RETRY_DELAY
        continue    # keep trying when call to api failed
    else
        log "apply request been ignored"
        msg="Task: $task"$'\n'
        msg+="Event: $event"$'\n'
        msg+="Result: ignored"
        report message "$msg"
        logIgnored "$toStat" "$ip" "$subject"
    fi
    break
done
