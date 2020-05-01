#!/bin/bash
# 1.1.1.1=1.2.2.2 1.3.3.3
# 1.2.2.2=2.2.2.1 2.2.2.2


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
    local groupName apiUrl msg
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

oneSshCmd() {
    local user id ip url size pnode sETag scripts arg snode mode sleepTime
    user=$1 id=$2 ip=$3 url="$4" size=$5 pnode=$6 sETag=$7 snode=$8 mode=$9 level=${10}
    scripts="/root/scripts/dist_doit.sh"
    sleepTime="0.5"
    #test "$size" -gt "104857600" && sleepTime="1.5"
    arg="${user} ${id} ${ip} \"${url}\" ${size} ${pnode} ${sETag} ${snode} ${mode} ${level} ${md5}"
    semrun $pnode $qlen \
    ssh -o ConnectTimeout=10 -o ConnectionAttempts=3 -o StrictHostKeyChecking=no \
    -p 9089 root@${ssh_ip} "nohup ${scripts} ${arg} </dev/null 2>&1 >/dev/null& { sleep $sleepTime && ${scripts} ${arg}; }"
    echo "status $?" > ${statusFile} 
}

sliceSshCmd() {
    local user id ip url size pnode sETag scripts arg snode mode sleepTime
    user=$1 id=$2 ip=$3 url="$4" size=$5 pnode=$6 sETag=$7 snode=$8 mode=$9 level=${10}
    scripts="/root/scripts/dist_doit.sh"
    sleepTime="0.5"
    #test "$size" -gt "104857600" && sleepTime="1.5"
    arg="${user} ${id} ${ip} \"${url}\" ${size} ${pnode} ${sETag} ${snode} ${mode} ${level}"
    ssh -o ConnectTimeout=10 -o ConnectionAttempts=3 -o StrictHostKeyChecking=no \
    -p 9089 root@${ssh_ip} "nohup ${scripts} ${arg} </dev/null 2>&1 >/dev/null& { sleep $sleepTime && ${scripts} ${arg}; }"
    echo "status $?" > ${statusFile} 
}

deleteSshCmd() {
    local user id ip url
    user=$1 id=$2 ip=$3 url="$4" 
    scripts="/root/scripts/dist_doit.sh"
    arg="${user} ${id} ${ip} \"${url}\""
    ssh -o ConnectTimeout=10 -o ConnectionAttempts=3 -o StrictHostKeyChecking=no \
    -p 9089 root@${ssh_ip} "${scripts} ${arg}"
    echo "status $?" > ${statusFile} 
}

joblist="$1"
user="$2"
id="$3"
url="$4"
ip="$5"
level="$6"
pnode="$7"
size="$8"
sETag="$9"
snode=${10}
mode=${11}
md5=${12}
qlen=10

echo "$0 $@" >> /tmp/cdnlog.log

if [ "$#" -lt "11" ];then
	echo "Usage:"
	echo "dist_dl joblist user id url ip level pnode size sETag snode mode" 
	exit 1
fi

ssh_ip=$ip
test "$ip" = '183.232.150.5' && ssh_ip='114.119.10.168'
test "$ip" = '183.232.150.4' && ssh_ip='114.119.10.169'

test ${level} -eq 1 && file=${level}_${ip} || file=${level}_${pnode}_${ip}

path=/tmp/cdnlogs/$id/$file
test -d /tmp/cdnlogs/$id || mkdir -p /tmp/cdnlogs/$id
statusFile=/tmp/cdnlogs/$id/status.log

if [ $mode -eq 2 -o $mode -eq 9 ]; then
    workingDir=$(cd $(dirname $0); pwd -P)
    sleep 5 ; bash $workingDir/dist_one.sh "$joblist" "$user" "$id" "$url" "$ip" "$level" "$size" "$sETag" "$mode" &
fi

upNode=$(awk -F "$snode=" '{print $2}' ${joblist})
i=0
while :
do  
    url=${url/vhost\//}
    if [ $mode -eq 9 ]; then
        let i++
        deleteSshCmd "$user" "$id" "$ip" "$url" 2>&1 | tee -a ${path}
        sta=$?
        grep -qw "status 255" ${statusFile}
        if [ $? -eq 0 ]; then
            sleep 3 
            echo > ${statusFile}
            continue
            test $i -gt 10 && break
        fi
        test "$sta" -ne 0 && titil="delete tempFile failed."
        break
    
    elif [ $mode -eq 2 ]; then
        let i++
        grep -qw "$ip" <<<"$upNode" || url=${url/http:\/\//http:\/\/vhost\/}
        sliceSshCmd "$user" "$id" "$ip" "$url" "$size" "$pnode" "$sETag" "$snode" "$mode" "$level" 2>&1 | tee -a ${path}
        sta=$?
        grep -qw "status 255" ${statusFile}
        if [ $? -eq 0 ]; then
            sleep 3 
            echo > ${statusFile}
            continue
            test $i -gt 10 && break
        fi
        titil="slice distribution"
        break
    
    elif [ $mode -eq 1 ]; then
        let i++
        oneSshCmd "$user" "$id" "$ip" "$url" "$size" "$pnode" "$sETag" "$snode" "$mode" "$level" "$md5" 2>&1 | tee -a ${path}
        sta=$?
        grep -qw "status 255" ${statusFile} 
        if [ $? -eq 0 ]; then
            sleep 3 
            echo > ${statusFile}
            continue
            test $i -gt 10 && break
        fi
        titil="routine distribution"
        break
    
    elif [ "x$mode" = "x" ]; then
        titil="distribution failed."
        echo "mode is null" | tee ${path}
        exit
    fi
done

if [ "$sta" -ne 0 ]; then
    errmsg=$(echo -e "$titil failed.\nfile: $id/$file .\n$(cat $path)")
    report warn "$errmsg"
fi

sum=$(curl -s -I ${url} -x $ip:80|grep " HIT" |wc -l)
mkdir -p /tmp/cdn/$user/$id/
if [ $sum -ne 0 ]; then
	echo "$url $ip  1" >> /tmp/cdn/$user/$id/access.log
else
	echo "$url $ip  2" >> /tmp/cdn/$user/$id/access.log
fi

sum_a=$(awk -F "=" '{print $2}' /tmp/cdnlogs/shell/$id | tr ' ' '\n'|grep -v "^$"|sort -n |uniq |wc -l)
sum_b=$(grep -v "^$" /tmp/cdn/$user/$id/access.log|wc -l)

if [ "$sum_a" -eq "$sum_b" ]; then
	echo "/tmp/cdn/$user/$id/access.log $size" >> '/tmp/ftpaccess.log'
fi

if [ $mode -eq 1 ]; then
    workingDir=$(cd $(dirname $0); pwd -P)
    bash $workingDir/dist_one.sh "$joblist" "$user" "$id" "$url" "$ip" "$level" "$size" "$sETag" "$mode" "$md5" &
fi
