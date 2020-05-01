#!/bin/bash

# Customers with rsync upload files to mydown 
# Take the domain name and file name from rsync.log composition URL
# Call API to distribute and refresh operations on the node

cleanup() {
    find "$log_dir" -mtime +15 -type f | xargs rm -f 
}
    
uploaded() {
    local user domain url
    user=$1
    domain=$2
    url=$3
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $url dist start" >> "$log_file"
    http_code=$(curl -o /dev/null -I -s -w %{http_code} "$url" -x 127.0.0.1:80)
    if [ "$http_code" == "200" ]; then
	    curl -d "url=$url" "http://my.down.speedtopcdn.com/index.php/ajax/purgeUrl" -x 127.0.0.1:80 &>/dev/null
        sleep 1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $url dist OK" >> "$log_file"
    fi
}

deleted() {
    local user domain url
    user=$1
    domain=$2
    url=$3
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $url del start" >> "$log_file"
    curl --retry 3 --retry-delay 10 --connect-timeout 300 -m 300 -d "rmurl=$url" "http://my.down.speedtopcdn.com/index.php/ajax/purgeUrl" -x 127.0.0.1:80 &>/dev/null
    sleep 1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $url del OK" >> "$log_file"
}

mark="<baodecdn>"
log_dir="/tmp/rsync-dist"
log_file="$log_dir/$(date +%y%m%d).log"
test -d "$log_dir" || mkdir "$log_dir"
#2016/07/04 12:00:46 [8122] <baodecdn> [114.119.10.163] (john) recv ::bb.jc.com download/apk/something.pak 4137 4096 download/apk/e.pak
#2016/08/17 03:52:05 [1538] <baodecdn> [121.34.108.208] (speedtop) recv ::dltest.borncloud.net dbd/test.file
#2016/07/04 11:58:08 [8088] <baodecdn> [114.119.10.163] (john) del. ::bb.jc.com t.php 0 0 %x
#2016/08/17 06:34:33 [8019] <baodecdn> [121.34.108.208] (baowang) del. ::phone.down.zqgame.com empty/gcc-linaro.tar.gz
tail -F -n0 /var/log/rsync/rsync.log | while read line
do
    items=(${line})
    if [ "${items[3]}" == "$mark" ]; then
        echo "Matched: $line" >> ${log_file}
        user="${items[5]}"
        oper="${items[6]}"
        domain="${items[7]}"
        filename="${items[8]}"
        domain=$(tr -d ':' <<<${domain})
        url="http://$domain/${filename}"

        if [ "$oper" == "recv" ]; then
            uploaded "$user" "$domain" "$url"
        elif [ "$oper" == "del." ]; then
            deleted "$user" "$domain" "$url"
        fi
    #else
        #echo "Ignored: $line"
    fi
done
