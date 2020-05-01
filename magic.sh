#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-07-20 17:34:38
# Location: Shenzhen
# Desc:     check access url evaluation score,
#           if score exceed threshold, push the url and score to wechat and DRMS. 
#

rePort() {
    local groupName apiUrl msg
    #groupName="PLCDN-SUPPORT"
    groupName="SUSPICIOUS"
    apiUrl="http://push.plcdn.net:7890/20160128"
    msg=$1
    #groupName=$2
    wgetArg='--tries=1 --timeout=30'
    wget -q --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null
}

makeMsg() {
    msg="# suspicious:"$'\n'
    msg+="--------------------"$'\n'
    msg+="URL: $Url"$'\n'
    msg+="Score: $score"$'\n'
    msg+="Node: $localIp"$'\n'
    msg+="cTime: $cTime"$'\n'
    msg+="Time: $(date '+%Y-%m-%d %H:%M:%S')"
}

makeToken() {
    token=$(echo -n "$score$key" | md5sum | awk '{print $1}')
}

toDrms() {
    curl -o /dev/null -s -d "url=$Url&score=$score&token=$token" $drmsApi
}

makeTodo() {
    totalNum=$(wc -l $doingList | awk '{print $1}')
    for ((i=1;i<=$preNum;i++))
    do
        randNum=$((RANDOM%$totalNum+1))
        sed -n "$randNum p" $doingList >> $tempfile
    done
    sort $tempfile | uniq > $toDoList 
}

cleanUp() {
    rm -f $toDoList $doingList $tempfile
}

drmsApi="http://drms.powerleadercdn.com/index.php/portal/urlPurify/"
localIp=$(awk '/bind/{print $2}' /etc/nginx/node.conf | tr -d ';')
queueList="/dev/shm/d-queue.lst"
doingList="/dev/shm/d-doing.lst"
nsfwAppDir="/opt/open_nsfw/"
tempfile=$(mktemp)
toDoList=$(mktemp)
key="portal"
threshold="9000"
preNum="130"

while : 
do
    if test -f $queueList; then
        mv $queueList $doingList
        makeTodo
        while read Url Size Hits Stat cTime
        do
            cd $nsfwAppDir
            score=$(bash nsfw.sh "$Url" 2>&1 | tail -1)
            grep -qE '[a-z]' <<<$score && continue
            if test $score -gt $threshold; then
                makeMsg
                makeToken
                rePort "$msg"
                toDrms
            fi
        done < $toDoList
        cleanUp
    else
        sleep 5
        continue
    fi
done

trap cleanUp exit
