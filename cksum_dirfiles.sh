#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2018-08-21 17:08:34
# Location: Dongguang
# Desc:     monitor dir files status, if changed then report
#

# set var
check_dir="$1"
dir_list=$(sed -r 's/,/ /' <<<"$check_dir")
local_user="$(whoami)"
cksum_res_file="/home/$local_user/.cksum_res_file"
test -d "/home/$local_user/" || mkdir "/home/$local_user"
test -f $cksum_res_file || touch $cksum_res_file


# print help message
echoHelp() {
    test $# -ne 1 && { echo "Usage: $0 dir[支持多个目录检测,目录之间用','分隔]"; exit; }
}


# report to xxxx 
reportMsg() {
    #send msg
    local sta_type=$1
    echo "Waring: $file is $sta_type [oldsum:$old_sum newsum:$new_sum]" | \
    tee -a /tmp/cksum_dirfiles.log
}


# flush cksum res file
flushRes() {
    local ck_file=$1 ck_old_sum=$2 ck_new_sum=$3
    sed -i "/$ck_old_sum/d" $cksum_res_file
    echo "$ck_new_sum  $ck_file" >> $cksum_res_file
}


# get dir files md5sum and save to $cksum_res_file
checkDirFiles() {
    local dir=$1
    find $dir -type f | while read file
    do
        if grep -qw "$file" $cksum_res_file; then
            old_sum=$(grep -wE "$file$" $cksum_res_file | awk '{print $1}')
            new_sum=$(md5sum $file | awk '{print $1}')
            if test "$old_sum" = "$new_sum"; then
                continue
            else
                reportMsg "changed" "$file"
                flushRes "$file" "$old_sum" "$new_sum"
            fi
        else
            reportMsg "add" "$file"
            md5sum $file >> $cksum_res_file
        fi
    done
}


# multi dir
for d in ${dir_list[*]}; do checkDirFiles $d; done
