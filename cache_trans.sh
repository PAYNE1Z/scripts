#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-06-11 10:48:13
# Location: Shenzhen
# Desc:     把旧的缓存文件以新的缓存命名方式到新的缓存规则目录
#

siteConfig="/etc/nginx/webconf.d/servers_upstreams.conf"
cacheDir="/data/cache1/data"

if test $# -eq 2; then
    cachedList=$(mktemp)
    echo "$1 $2" > $cachedList
else
    cachedList="/dev/shm/cached.list"
fi

sort -k2,2r $cachedList | while read dir uri
do
    echo "## URL: http://$uri"
    echo "## OLD-FILE: $dir"
    moveDir=$(sed "s#$cacheDir##" <<<$dir)
    subDir=${moveDir%/*}
    cacheFile=${dir##*/}
    domain=$(awk -F/ '{print $1}' <<<$uri)
    domainID=$(grep -A5 "server_name $domain" $siteConfig | awk -F ' |;' '/site_id/{print $(NF-1)}')
    if test -z "$domainID"; then
        suffix=$(awk -F. '{print $1}' <<<$domain)
        domain=$(sed -r "s/^$suffix/\\\*/" <<<$domain)
        domainID=$(grep -A5 "server_name $domain" $siteConfig | awk -F ' |;' '/site_id/{print $(NF-1)}')
	    test -z "$domainID" && continue
    fi
    # domIdHex 十六进制的域名ID号
    domIdHex=$(awk '{printf "%04x",$0}' <<<$domainID)
    moveDstDir="$cacheDir/$domIdHex$subDir"
    moveDstFile=$(sed -r "s/(.{22})(.{4})(.{6})/\1\3$domIdHex/" <<<$cacheFile)
    echo "## NEW-FILE: $moveDstDir/$moveDstFile"
    if test ! -d $moveDstDir; then 
        mkdir -m 700 -p $moveDstDir
        chown -R nginx:nginx $moveDstDir
    fi
    mv $dir $moveDstDir/$moveDstFile
done

rm -f $cachedList
