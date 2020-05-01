#!/bin/bash

#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-05-11 16:11:07
# Location: Shenzhen
# Desc:     ssh connect remote host
#

chkExit() {
    test "$1" = q -o "$1" = Q -o "$1" = "exit" -o "$1" = "Exit" && \
    { echo;exit; }
}

cleanUp() {
    rm -f $matchiplist
}

echoColor() {
    while read n w 
    do
        echo -e "\E[1;34m $n \E[1;32m $w \E[0m"
    done
}

test $# -ne 1 && \
{ echo -e '\E[1;36m Use: sshp ipfield \E[0m';exit; }
todoip=$1
matchiplist=$(mktemp)
hostlist=/etc/ansible/hosts
ssharg="-o ConnectTimeout=10 -o ConnectionAttempts=3 -o StrictHostKeyChecking=no"

mathip=$(grep $todoip $hostlist  | grep -vE '^#|^ #' | awk -F: '{print $1}' | sort | uniq | wc -l)
grep $todoip /etc/ansible/hosts  | grep -vE '^#|^ #' | awk -F: '{print $1}' | sort | uniq > $matchiplist

test $mathip -eq 0 && { echo -e '\E[1;31m No match... Retry. \E[0m';exit; } 

if test $mathip -eq 1; then
    read remoteip < $matchiplist
    echo -e "\E[1;35m Match remote host: $remoteip \E[0m"
    echo -e "\E[1;32m connect to $remoteip ... \E[0m"
    ssh $ssharg -p9089 root@$remoteip
else
    echo -e '\E[1;35m Match remote hosts: \E[0m'
    cat -n $matchiplist | echoColor
    echo -ne '\E[1;36m Enter the sernum select the remote host to connect: \E[0m'
    read -t30 snum
    snum=${snum:-q}
    chkExit $snum
    while :
        do
            remoteip=$(sed -n "${snum}p" $matchiplist 2>/dev/null)
            if grep -qE '^[0-9]+$' <<<$snum; then
                if test -z "$remoteip"; then
                    echo -ne '\E[1;31m No match... Reenter: \E[0m'
                    read -t30 snum
                    snum=${snum:-q}
                    chkExit $snum
                    continue
                else
                    break
                fi
            else
                echo -ne '\E[1;31m Illegal string... Reenter: \E[0m'
                read -t30 snum
                snum=${snum:-q}
                chkExit $snum
                continue
            fi
        done
    echo -e "\E[1;32m connect to $remoteip ... \E[0m"
    ssh $ssharg -p9089 root@$remoteip
fi 

trap cleanUp exit
