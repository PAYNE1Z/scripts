#!/bin/bash
#
# Author: Joshua Chen
# Date: 2016-04-12
# Location: Shenzhen
# Desc: backup MySQL database, save in compressed form,
# parallel tool is used to boost compression speed.
#

log(){
    logger -t "[MySQL Backup]" -p local0.info "$*"
}

runSQL() {
    mysql -h $host -u$user -p$pass -e "$*"
}

# to ensure the dumped data synced with
# the position of the master log position
preAction() {
    runSQL "stop slave io_thread;"  # freeze the master log position
    waitSQLThread                   # wait for SQL thread to apply
    runSQL "show slave status\G" > $statusFile  # record the master log state
    runSQL "stop slave sql_thread;" # prevent changes to the database from sql_thread
    runSQL "start slave io_thread;" # but continue to receive log from the master
}

postAction() {
    runSQL "start slave sql_thread;"
}

# wait for the SQL thread to apply all logs from the master
waitSQLThread() {
    while true
    do
        text=$(runSQL "show slave status\G")
        text=$(awk -F ": " '$1 ~ /Master_Log_Pos/ {print $2}' <<< "$text")  # extract the numbers
        if test $(sort -u <<< "$text" | wc -l) -eq 1; then                  # all read log executed
            break
        fi
    done
}

dumpOne() {
    local db=$1 file
    file="${dstDir}/${db}.${time}.sql.bz2"
    log "dump start: $db"
    $dumper -h $host -u $user -p$pass \
        --lock-all-tables \
        --flush-logs \
        --databases $db | lbzip2 > "$file"
    log "dump end: $db"
}

host="127.0.0.1"
user="backup"
pass="backup"
time=$(date '+%Y%m%d%H%M%S')
dumper="/usr/local/mysql/bin/mysqldump"
backupDir="/data/backup"
dstDir="$backupDir/$time"
statusFile="${dstDir}/status.${time}"
mkdir -p $dstDir

log "start to work"
preAction
for db in pcdn acoway_oss acoway_oss_yunduan acoway_manage mysql
do
    dumpOne $db
done
postAction
log "work end"
