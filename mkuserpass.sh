#!/bin/bash

#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-11-01 15:27:19
# Location: DongGuang
# Desc:     crate openvpn user and hash-password
#

Help() {
    echo "Usage: $0 cuser[jielun.zhou]|cuserlist[/tmp/tdwcuser.list]"
    exit
}

checkExist() {
    if grep -qE "^$cuser" $pass_list; then
        exist_pass=$(grep -E "^$cuser" $pass_list | awk '{print $2}')
        echo "cuser $cuser is already exist"
        echo "cuser $cuser passwd is $exist_pass"
        #read -p "If you need to change the password, please enter [y|Y|yes]:" tag
        #if test "$tag" != "y" -o "$tag" != "Y" -o "$tag" != "yes"; then
        #    return 1
        #else
        #    return 0
        #fi
    fi
}

makeUserPass() {
    cusername=$cuser$((RANDOM%8999+1000))
    password=$(mkpasswd -l 15 payne)
    hashpass=$(php -r "echo password_hash('$password',PASSWORD_DEFAULT);")
    echo "$cusername $password" >> $pass_list
    echo "import password to MySQL.."
    importMysql
    echo "import MySQL OK"
}

importMysql() {
    . /etc/openvpn/scripts/config.sh
    mysql -u$user -p$pass -e \
    "insert into ${db}.user (user_id,user_pass) values('$cuser','$hashpass');"
}

printMsg() {
    echo "User: $cusername create success"
    echo "Username: $cusername"
    echo "Password: $password"
}

cuser=$1
pass_list=/root/tdwvpn.pass
pass_dir=/root/tdwvpn
temp_cuser_list=$(mktemp)
test ! -d $pass_dir && mkdir $pass_dir

test $# -ne 1  && Help
test ! -f $1 && echo "$1" > $temp_cuser_list || cat $1 | sed -r '/^$/d' > $temp_cuser_list
            
while read cuser
    do
        if grep -qE "^#" <<<$cuser; then
            dep=${cuser:1}
            pass_list=$pass_dir/$dep
            test ! -f $pass_list && touch $pass_list
            continue
        fi
        checkExist
        test $? -ne 0 && continue
        makeUserPass
        printMsg
    done < $temp_cuser_list

rm -f $temp_cuser_list
