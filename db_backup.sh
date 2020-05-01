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
    $mysql -h $host -u$user -p$pass -e "$*"
}

# Actions to perform before dump.
# We mark down the 'revision' of the backup data here,
# the 'revision' is identified by the slave status.
preAction() {
    mkdir "$dstDir"
    runSQL "stop slave sql_thread;"     # prevent changes to the database from sql_thread
    runSQL "show slave status\G" > $statusFile  # record the master log state
    if test $? -ne 0; then
        runSQL "start slave sql_thread;"
        msg="failed to record the slave status, abort"
        log "$msg"
        exit 1
    fi
}

postAction() {
    runSQL "start slave sql_thread;"
}

dumpOneTb() {
    local db=$1 tb=$2 file stat
    file="${dstDir}/${db}.${tb}.sql.bz2"
    log "dump start: ${db}.${tb}"
    $dumper -h $host -u $user -p$pass $db $tb | $compressor > "$file"
    test $? -eq 0 && stat="success" || stat="failed"
    log "dump end: ${db}.${tb}, $stat"
}

# Collect all table names in the databases
# The first argument is the file to write into
# all subsequent arguments are database names
collectTbNames() {
    local tableList db
    tableList=$1
    shift
    :> "$tableList"
    for db in "$@"
    do
        runSQL "show tables from $db" | \
        sed -r -e 1d -e "s/^/${db}./" >> "$tableList"
    done
}

cleanup() {
    rm -f $tableList $lock $taskRecord
}

host="127.0.0.1"
user="backup"
pass="backup"
time=$(date '+%Y%m%d%H%M%S')
dumper="/usr/local/mysql/bin/mysqldump"
mysql="/usr/local/mysql/bin/mysql"
compressor="/usr/local/bin/lbzip2"
backupDir="/data/backup"
dstDir="$backupDir/$time"
statusFile="${dstDir}/status"
dbList="pcdn acoway_oss statis acoway_manage mysql"
tableList=$(mktemp)

# import the parallel task manager functions
source /etc/rc.d/init.d/ptm
limit=6                 # max parallel task
lock=$(mktemp)          # lock file for the ptm
taskRecord=$(mktemp)    # record file for the ptm

trap cleanup exit

log "start to work"
preAction
collectTbNames "$tableList" $dbList
while IFS=. read db tb
do
    pexec $limit $lock $taskRecord dumpOneTb "$db" "$tb"
done < "$tableList"
wait
postAction
log "work end"
