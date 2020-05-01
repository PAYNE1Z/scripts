#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-05-22 20:24:19
# Location: Shenzhen
# Desc:     all nodes random access www.plcdn.cn ensure site activity
#

cleanUp() {
    rm -f $userAgentList
    rm -rf /dev/shm/www.speedtopcdn.com
}

# set variable
ngxLog=/var/log/nginx/bdrz.log
userAgentList=$(mktemp)
conUrl="http://www.speedtopcdn.com/"
defUserAgent="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36"

# get accesslog user agent
tail -100 $ngxLog | awk -F'"' '{print $(NF-1)}' | sort | uniq > $userAgentList
userAgent=$(sed -n "$(($RANDOM%$(wc -l $userAgentList|awk '{print $1}')+1))p" $userAgentList)
test -z "$userAgent" && userAgent=$defUserAgent

# random seconds to access in an hour
sleep $(($RANDOM%3600+1))
wget --tries=2 --timeout=30 --limit-rate=100k --level=1 --recursive --user-agent="$userAgent" -P /dev/shm  $conUrl

# clear temp file
trap cleanUp exit
