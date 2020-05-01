#!/bin/bash
# Author: Joshua Chen <iesugrace@gmail.com>
# Date: 2016-05-19
# Location: Shenzhen
# Desc: Temporary solution for the import monitor,
#       it shall be retired when the new Access
#       Statistics System is online.
#

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
    msg=$'Flow import:\n'
    msg+="$2"$'\n'
    msg+="Time: $(date +'%F %T')"
    wget -q --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null

    logReport $? "$groupName" "$apiUrl" "$msg"
}

checkImporterStat() {
    if test $1 -ne 0; then
        msg="importer failed, code=$1"
        report warn "$msg"
    fi
}

# When failure occurred due to primary key conflict,
# the record files will be placed to a directory,
# we check if there is any new file in that directory.
checkImportFailure() {
    failureList=$(find "$failureDir" -newerct "$lastTime" -name "countfile.*" -type f)
    if test -n "$failureList"; then
        n=$(wc -l <<< "$failureList")
        amount=$(echo "$failureList" | xargs cat | awk '{a+=$5}END{print a/1024/1024/1024}')
        msg=$'import failed:\n'
        msg+="Number of files: $n"$'\n'
        msg+="Amount of flow: ${amount}GB"$'\n'
        msg+="File list:"$'\n'
        msg+="$failureList"
        report warn "$msg"
    fi
}

# We check for the flow records only for now.
checkDelayedUpload() {
    local missedNamePat='.TempFlowUploadInfo.??????????????'
    local missedList missedRecordList
    local n msg
    missedList=$(find "$importerLogDir" -newerct "$lastTime" \
                    -name "$missedNamePat" \! -empty)
    if test -n "$missedList"; then
        missedRecordList=$(echo "$missedList" | xargs -r cat | sort -u)
        missedRecordList=$(filterMissedRecord "$missedRecordList")
        n=$(echo "$missedRecordList" | wc -l)
        msg=$'delayed upload:\n'
        msg+="Number of records: $n"$'\n'
        msg+="Record list:"$'\n'
        msg+="$missedRecordList"
        report info "$msg"
    fi
}

# remove the uploaded-missed records from the missed list
filterMissedRecord() {
    local prefix="/data/back/flow"
    local input=$1
    local period1=1500   # 25 minutes, determine directories
    local period2=1800   # 30 minutes, filter files

    # 1. select the directories to search from,
    #    today or today and yesterday.
    today=$(date '+%Y%m%d')
    today_ts=$(date +%s -d $today)
    now_ts=$(date +%s)
    if test $((now_ts - today_ts)) -lt $period1; then
        yesterday=$(date '+%Y%m%d' -d "$today -1day")
        dirs="$prefix/$yesterday $prefix/$today"
    else
        dirs="$prefix/$today"
    fi

    # 2. build the find arguments
    timearg=$(date '+%Y-%m-%d %H:%M' -d "-$period2 seconds")
    node_nums=$(awk '{print $2}' <<< "$input" | sort -u)
    find_args=
    while read node
    do
        find_args+="-name 'countfile.*.$node' -o "
    done <<< "$node_nums"
    find_args=$(sed -r 's/ -o $//' <<< "$find_args")
    find_args="'(' $find_args ')' -newerct '$timearg'"

    # 3. match file name pattern and time for each node,
    #    concatenate all found files' field 2 and field 3.
    tmpfile=$(mktemp)
    eval find $dirs $find_args | xargs -r awk '{print $2, $3}' | sort -u > $tmpfile

    # 4. remove all that are in the 'uploaded' list
    result=$(diff <(sort <<< "$input") $tmpfile | sed -r -n '/^</s/^..//p')
    rm -f $tmpfile
    echo "$result"
}

progDir=$(cd $(dirname $0); pwd)
bin_importer="$progDir/bin_importer"
bin_importer_conf="$progDir/bin_importer.conf"
timeLog="$progDir/time.log"
failureDir="/data/import_failure"
importerLogDir="/data/program/flow/new_importer/log"
importType=1   # 1 is for importing flow records
$bin_importer $bin_importer_conf $importType
stat=$?
lastTime=$(cat $timeLog)
test -z "$lastTime" && lastTime="1970-01-01"
checkImporterStat $stat
checkImportFailure
checkDelayedUpload
date '+%Y-%m-%d %H:%M:%S' > "$timeLog"
