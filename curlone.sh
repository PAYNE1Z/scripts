#!/bin/bash

url=$1
bad_ip=$2
trip=$3
md5=$4
ip=$5
temp_file=$(mktemp)
tempUrl=${url#*//}
domain=${tempUrl%%/*}
file=${tempUrl#*/}
HEAD=${url%:*}
local_ip=$(/sbin/ifconfig | grep "inet addr" | grep -v 127.0.0.1 | awk '{print $2}' | tr -d "addr:" | head -1)
grep -q ':' <<<$ip || ip="$ip:80"

if [ $HEAD = http ]; then
    curlCmd="curl --retry 3 -m 10 -I $url -x $ip"
else
    curlCmd="curl --retry 3 -m 10 -Ik \'$HEAD://$ip/$file\' -H \'$domain\'"
fi
wgetCmd="wget $url -e http-proxy=$ip -O-"

culOne() {
    local ip=$1 bad_ip=$2 checkCmd="$3" temp_file=$4 trip=$5
    grep -qw "${ip%%:*}" $bad_ip
    if [ $? -ne 0 ]; then
        $checkCmd 2>/dev/null >$temp_file 
        sta=$?
        test $sta -ne 0 && flag=ERROR || flag=
    else
        ping -c 1 $trip &>/dev/null
        test $? -ne 0 && trip=114.119.10.169
        ssh -p9089 root@$trip "$checkCmd" 2>/dev/null >$temp_file
        sta=$?
        test $sta -ne 0 && flag=ERROR || flag=
        local_ip=183.232.150.5
    fi
}

wgeOne() {
    local ip=$1 bad_ip=$2 checkCmd="$3" temp_file=$4 trip=$5
    grep -qw "${ip%%:*}" $bad_ip
    if [ $? -ne 0 ]; then
        $checkCmd 2>/dev/null | md5sum >$temp_file 
        sta=$?
        test $sta -ne 0 && flag=ERROR || flag=
    else
        ping -c 1 $trip &>/dev/null
        test $? -ne 0 && trip=114.119.10.169
        ssh -p9089 root@$trip "$checkCmd | md5sum" 2>/dev/null >$temp_file
        sta=$?
        test $sta -ne 0 && flag=ERROR || flag=
        local_ip=183.232.150.5
    fi
}

echo "$(date '+%Y%h%m %H%M%S') : $(basename $0) : $@" >> /tmp/debug.log
culOne "$ip" "$bad_ip" "$curlCmd" "$temp_file" "$trip"

echo "$(date +%Y%m%d-%H:%M:%S) : $ip : $url" >> /tmp/refresh_ngctool.log
cat "$temp_file" >> /tmp/refresh_ngctool.log
SIZE=$(awk '/^Content-Length/{print $2}' $temp_file | tr -d '\r')
STAT=$(awk '/^HTTP/{print $2}' $temp_file)
ETAG=$(awk '/^ETag:/{print $2}' $temp_file | tr -d '"' | tr -d '\r')
HIMI=$(awk '/^Powered/{print $2}' $temp_file)
LSMD=$(awk '/^Last-Modified/{print $2,$3,$4,$5,$6,$7}' $temp_file | tr -d '\r')

if test $md5 = 'md5'; then
    wgeOne "$ip" "$bad_ip" "$wgetCmd" "$temp_file" "$trip"
    MD5=$(awk '{print $1}' $temp_file)
    echo "$(date +%Y%m%d-%H:%M:%S) : $ip : $url : $(cat $temp_file)" >> /tmp/refresh_ngctool.log
fi

if [ -z "$flag" ]; then
    echo "${ip%%:*}" "$STAT" "$ETAG" "$SIZE" "\"$LSMD\"" "$HIMI" "$local_ip" "$MD5"
else
    echo "${ip%%:*}" "\"$flag code:$sta\"" #>> /tmp/ok.log
fi

rm -rf $temp_file
rm -rf $temp_file
