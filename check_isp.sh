#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-01-12 09:27:39
# Location: Shenzhen
# Desc:     check any in dns server ip is isp 
#

# Help function
Help() {
     echo "Usega : $(basename $0) ip_list interval"
     echo "example : bash $(basename $0) /root/sh.txt 2"
}

# log function
log() {
    logger -t "CHECK_ISP" -p local0.info "$*"
}

# set variable
ip_list=$1
interval=$2
outdir=/data/check_isp/$(date '+%Y%m%d%H%M')
test ! -d $outdir && mkdir -p $outdir
outfile=$outdir/ALL_check_isp.log
cn_outfile=$outdir/CN_check_isp.log
failed_file=$outdir/failed_ip.list
python_script=/root/conv.py

# To write python3 script
cat > $python_script <<EOF
#!/usr/bin/env python3

import sys
import os
import json
from subprocess import Popen, PIPE

def fetch(ip):
    url = 'http://ip.taobao.com/service/getIpInfo.php'
    url = '%s?ip=%s' % (url, ip)
    pipe = Popen(['curl', url], stdout=PIPE, stderr=PIPE)
    stdout, stderr = pipe.communicate()
    res = json.loads(stdout.decode('utf8'))
    if res['code'] != 0:
        exit(1)
    else:
        data = res['data']
        country = data['country']
        country_id = data['country_id']
        region = data['region']
        city = data['city']
        isp = data['isp']
        ip = data['ip']
        print(country_id, ip, country, region, city, isp)
        exit(0)

if __name__ == '__main__':

    if len(sys.argv) != 2:
        bname = os.path.basename(sys.argv[0])
        print("usage: %s TEXT" % bname, file=sys.stderr)
        exit(1)

    ip = sys.argv[1]
    fetch(ip)
EOF

# check args 
test $# -ne 2 && { Help;exit; } 

# log mark start time
log "check start.."

# loop read checkip action to python3 script
while read ip 
do
    let i++
    echo "NO:$i"
    python3 $python_script $ip >> $outfile
    if test $? -ne 0; then
        sleep 1;
        python3  $python_script $ip >> $outfile
        test $? -ne 0 && echo "$ip" >> $failed_file
    fi
    sleep $interval
done <$ip_list

# log mark end time
log "check done.."

# filter country_id is "CN" 
grep -wE "^CN" "$outfile" > "$cn_outfile"

# end echo information
echo "check done..."
echo "All test results file : $outfile"
echo "CN test results file : $cn_outfile"
echo "check failed file : $failed_file"

# delete python3 script tempfile
rm -f $python_script
