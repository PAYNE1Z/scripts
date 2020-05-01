#!/bin/bash
# 1.1.1.1=1.2.2.2 1.3.3.3
# 1.2.2.2=2.2.2.1 2.2.2.2

inform_stat() {
    local id=$1
    curl "http://my.down.speedtopcdn.com/index.php/ajax/distStat?id=$id" -x 127.0.0.1:80
}

oneLoop() {
    list="$(grep ${ip}= ${joblist} | awk -F '=' '{print $2}')"
    if [ -n "${list}" ]; then
	    for node in ${list}
        do
            chk="/tmp/cdn/${id}/${node}"
            chkres=$(flock -x "/tmp/cdn/${id}/.lock" -c "[ ! -f ${chk} ] && touch ${chk} && echo Go")
            if [ "${chkres}" = "Go" ]; then
                bash $workingDir/dist_dl_one.sh ${joblist} ${user} ${id} "${url}" ${node} ${level} ${ip} ${size} ${sETag} ${snode} ${mode} ${md5} &
            fi
	    done
        jobs
        echo "Waiting for jobs to finish"
        wait
    fi
}

sliceLoop() {
    list="$(grep ${ip}= ${joblist} | awk -F '=' '{print $2}')"
    if [ -n "${list}" ]; then
	    for node in ${list}
        do
            bash $workingDir/dist_dl_one.sh ${joblist} ${user} ${id} "${url}" ${node} ${level} ${ip} ${size} ${sETag} ${snode} ${mode} &
	    done
    fi
}

joblist="$1"
user="$2"
id="$3"
url="$4"
ip="$5"
level="$6"
size="$7"
sETag=$8
mode=$9
md5=${10}
snode=$(/sbin/ifconfig | grep "inet addr" | grep -v 127.0.0.1 | awk '{print $2}' | tr -d "addr:" | head -1)

if [ "$ip" == "127.0.0.1" ]; then
     ip="$snode"
     sed -i -r "s/\<127.0.0.1\>/${snode}/" ${joblist}
fi

# tage=1 common distribution
# tage=2 section upload and distribution
# tage=9 delete node temp file

workingDir=$(cd $(dirname $0); pwd -P)

echo [`date "+%Y-%m-%d %H:%M:%S"`]   $@  >> /tmp/cdnlog.log

if [ "$#" -lt "9" ];then
	echo "Usage:"
	echo "$(basename $0) joblist user id url ip level size sETag mode" 
	exit 1
fi

if [ "$level" = "0" ];then
    rm -rf /tmp/cdn/${id}
    rm -rf /tmp/cdnlogs/${id}
    rm -rf /tmp/cdnlogs.ssh/${user}/${id}
	mkdir -p /tmp/cdn/${id}
	mkdir -p /tmp/cdnlogs/${id}
	mkdir -p /tmp/cdnlogs.ssh/${user}/${id}
fi

let level++
test $mode -eq 2 -o $mode -eq 9 && sliceLoop
test $mode -eq 1 && oneLoop

if [ "$level" = "2" ];then
    wait
    #while :
    #do
    #    backPros=$(ps -ef| grep "${url}" | grep -v grep | wc -l)
    #    if [ $backPros -eq 0 ]; then 
            inform_stat "$id"
    #        break
    #    else
    #        sleep 1 && continue
    #    fi
    #done
fi
