#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2016-12-12 04:40:07
# Location: Shenzhen
# Desc:     check refresh file ETag
#

cleanUp() {
    rm -f $bad_ip
}

trip=114.119.10.168
bad_ip=$(mktemp)
check_url=$1
sip=$2
md5=$3
test -z "$4" && read ip_list || ip_list=$4

curlOne=/var/www/html/demo/ftp/test_shell/curlone.sh

echo "$(date '+%Y%h%m %H%M%S') : $(basename $0) : $@" >> /tmp/debug.log
echo "$ip_list" >> /tmp/debug.log
cat > $bad_ip <<EOF
221.7.252.107
183.240.18.66
183.232.150.4
183.232.150.5
EOF

#xargs -P20 -n1 <<<$ip_list bash $curlOne "$check_url" "$bad_ip" "$trip"
if test $md5 = 'md5'; then
    xargs -P20 -n1 <<<$sip bash $curlOne "$check_url" "$bad_ip" "$trip" "$md5"
    sleep 1
    xargs -P20 -n1 <<<$ip_list bash $curlOne "$check_url" "$bad_ip" "$trip" "$md5"
else
    xargs -P20 -n1 <<<$sip bash $curlOne "$check_url" "$bad_ip" "$trip" "$md5"
    sleep 1
    xargs -P20 -n1 <<<$ip_list bash $curlOne "$check_url" "$bad_ip" "$trip" "$md5"
fi

trap cleanUp exit
