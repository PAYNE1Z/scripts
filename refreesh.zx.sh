#!/bin/bash
# Author: Joshua Chen
# Date: 2015-12-17
# Location: Shenzhen
# Desc: refresh CDN nodes.

help() {
    echo "Usage:"
    echo "$(basename $0) DEVICE-FILE URL-FILE TASK-TYPE TASK-ID TOP-DEVICE URL-TYPE"
}

log() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") $*" >> $logfile
}

put() {
# 单个设备status标志方法：0表示失败，1表示成功。
    local task_id device_ip status device_id curl_stdout
    task_id=$1
    device_ip=$2
    status=$3
    curl_stdout=$4
    device_id=$(grep "$device_ip" $serverlist | awk '{print $1}')
    curl -s -d "$text" "http://$reportserverip:$reportserverport/index.php/api/taskUpdate?id=$task_id&device_id=$device_id&status=$status"
}

# 递归遍历所有设备
# 当前节点刷新完成之后，就通过并行的方式刷新其所有下层节点
# 第四个参数用于控制是否刷新当前设备，这个参数的引入是为了
# 在处理源设备时使用，处理源设备时不需要刷新当前设备。
walk_devices() {
    local device device_file url_file ignore_current device_type device_ip
    device=$1
    device_file=$2
    url_file=$3
    ignore_current=$4
    # 当把源设备的信息传进来时，该信息的是不包含a 或者n 的，
    # 但下层的设备信息中都包括了该字符，这里分别对待。
    if test -z "$ignore_current"; then
        device_type=$(echo "$device" | cut -b1)
        device_ip=$(echo "$device" | cut -b2-)
        refresh "$device_type" "$device_ip" "$url_file"
    else
        device_ip=$device
    fi
    sub_devices=$(awk -F= '$1 == "'$device_ip'" {print $2; exit}' $device_file)
    for subdev in $sub_devices
    do
        walk_devices "$subdev" "$device_file" "$url_file" &
    done
    wait
}

# Refresh all URLs in the url file for a single device,
# multiple processes may try to refresh one same device,
# so acquire a lock before proceeding, and release the
# lock when the whole device is finished. Acquire lock in
# a blocking way, block for 'lock_tmout' seconds, if the
# 'lock_tmout' is zero, block for ever. When get the lock,
# check if the device is already processed.
refresh() {
    local device_type device_ip url_file lock flag
    local ftype dtype text
    ftype=1
    dtype=2
    success_status=1
    fail_status=0
    device_type=$1
    device_ip=$2
    url_file=$3
    lock="$locks_dir/$device_ip"
    flag=done
    test "$lock_tmout" -gt 0 && tmout="-w$lock_tmout" || tmout=
    (
        flock -x $tmout 3 || exit 1
        test "$(cat $lock)" = $flag && exit 0
        while read url
        do
            text=$(refresh_one_url "$device_type" "$device_ip" "$url")
            test $? -eq 0 && status=$success_status || status=$fail_status
            if [ $url_type = $ftype ]; then
                put $task_id $device_ip $status "$text"
            fi
        done < "$url_file"
        if [ $url_type = $dtype ]; then
            put $task_id $device_ip $success_status
        fi
        echo "$flag" >&3
    ) 3>> $lock
}

# Refresh one url for one device, task_type is a
# normal variable that set outside this function.
refresh_one_url() {
    local device_type device_ip url res purge preget text
    device_type=$1
    device_ip=$2
    url=$3
    res=OK
    purge=2
    preget=1

    text=$(refresh_real "$device_ip" "$url" "$device_type" 2>&1)

    if [ $? -eq 0 ]; then
        if [ "$task_type" = "$preget" ]; then
            text=$(get "$device_ip" "$url" 2>&1)
            test $? -ne 0 && res=Failed_preget
        fi
    else
        res=Failed
    fi
    log "$res:$device_ip:$url"
    test "$res" = OK
    stat=$?
    echo "$text"
    return $stat
}

refresh_real() {
    local ip url dt
    ip=$1
    url=$2
    dt=$3
    if [ "$dt" = n ]; then
        curl -sS --retry 3 --retry-delay 10 -k -m "$curl_tmout" -I $url -x $ip:80 -H "X-MPROXY-PURGE: 1"
    else
        curl -sS --retry 3 --retry-delay 10 -k -m "$curl_tmout" "http://$ip/delete_url?url=$url"
    fi
}

cleanup() {
    rm -rf $locks_dir
}

if [ $# -ne 6 ]; then
    help >&2
    exit 1
fi


device_file="$1"
url_file="$2"
task_type="$3"
task_id="$4"
top_device="$5"
url_type="$6"
locks_dir=$(mktemp -d)
lock_tmout=10
curl_tmout=10
logdir=/var/log/refresh
mkdir -p "$logdir"
logfile=$logdir/refresh_$task_id.log
reportserverip=127.0.0.1
reportserverport=83
serverlist=/data/vhosts/speedtopcdn.com/web/files/serverlist.txt

trap cleanup exit
log "$*"
walk_devices "$top_device" "$device_file" "$url_file" ignore_current
