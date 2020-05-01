#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: init.sh                                          #
# ScriptsPath:/github/scripts/init.sh                           #
# Purpose: initialization installed node system                 #
# Edition: 1.2                                                  #
# CreateDate:2016-04-12 13:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

clean_up() {
    rm -rf $baseDir
}

log() {
    local tag="NODE-INIT" pri="local0.info"
    logger -t "$tag" -p "$pri" "$*"
}

# Execute command with the provided arguments,
# log the state, exit if the command failed.
perform() {
    local cmd cmdline stat
    cmdline="$*"
    cmd=$1
    shift
    test "$VERBOSE" = 1 && echo "execute: $cmdline"
    $cmd "$@" &> /tmp/init.log
    stat=$?
    test $stat -eq 0 && resText=OK || resText=FAILED
    msg="$resText: $cmdline"
    log "$msg"
    test "$VERBOSE" = 1 && echo "$msg"
    test $stat -ne 0 && exit 1
}

install_wget() {
    which wget || \
    yum install wget -y &> /dev/null
}

begin_info() {
    localtime=$(date | grep -owE "[A-Z]+")
    [ $localtime != CST ] && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 
    wget --spider http://$file_server/zabbix-2.2.2.tar.gz &>/dev/null
    [ $? -ne 0 ] && { echo -e "$RED_COLOR== ERROR: wget faild, check your file server! ==$RES"; exit; }
}

setHostName() {
    local hostname=$1 config=/etc/sysconfig/network
    sed -i -r "s/^(HOSTNAME)=.*/\\1=$hostname/" "$config"
}

install_163_repo() {
    local repoDir repoFile repoUrl keyFile
    repoDir="/etc/yum.repos.d"
    repoFile="$repoDir/CentOS6-Base-163.repo"
    oldrepoFile="$repoDir/CentOS-Base.repo"
    repoUrl="http://mirrors.163.com/.help/CentOS6-Base-163.repo"
    keyFile="/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6"
    rpm -ivh http://mirrors.aliyun.com/epel/epel-release-latest-6.noarch.rpm
    test -f $oldrepoFile && mv $oldrepoFile{,.bak}
    if [ ! -f "$repoFile" ]; then
        wget -q -O "$repoFile" "$repoUrl" &> /dev/null
        yum makecache &> /dev/null
        rpm --import "$keyFile"
        yum repolist | grep -E "163.com|epel" &> /dev/null
        test $? -ne 0 && { rm -f "$repoFile"; return 1; }
    fi
    return 0
}

install_common_tools() {
    local list
    systemvs=$(cat /etc/issue | awk '/release/{print $3}')
    [ "$systemvs" = "6.7" ] && rpm -i http://$file_server/kernel-headers-2.6.32-573.el6.x86_64.rpm
    list+="rsync dmidecode unzip iptraf git initscripts shadow-utils lsof"
    list+=" nload dnsmasq logrotate tree vixie-cron screen bc sysstat man patch inxi"
    list+=" vim lrzsz lsof tcpdump telnet nc ntp expect banner figlet mtr bind-utils"
    yum install -y $list
}

install_prebuilt_tools() {
    local urls prefix sbin bin prog src dst
    #urls+="http://$file_server/miniconda2.tar.bz2"$'\n'
    urls+="http://$file_server/lbzip2.tar.bz2"$'\n'
    urls+="http://$file_server/iftop.tar.bz2"
    prefix=/usr/local
    sbin=/usr/sbin
    bin=/usr/bin

    wget -P $baseDir $urls
    for file in $baseDir/*.bz2
    do
        tar xf $file -C $prefix
    done

    prog=iftop
    src=$prefix/$prog/sbin/$prog
    dst=$sbin/$prog
    ln -s $src $dst

    prog=lbzip2
    src=$prefix/$prog/bin/$prog
    dst=$bin/$prog
    ln -s $src $dst

    #prog=ipython
    #src=$prefix/miniconda2/bin/$prog
    #dst=$bin/$prog
    #ln -s $src $dst
}

config_time_sync() {
    local cronFile='/var/spool/cron/root'
    local url="http://$file_server/time_sync.sh"
    wget -q "$url" -P /root/scripts/
    chmod 755 /root/scripts/time_sync.sh
    echo 'MAILTO=""' > "$cronFile" # crond任务脚本输出不发送邮件
    echo '20 * * * * bash /root/scripts/time_sync.sh &>>/dev/null' >> "$cronFile"
    chkconfig --level 2345 ntpd off
    chkconfig --level 2345 ntpdate off
}

cat > /tmp/netstop.sh <<EOF
#!/bin/bash
/sbin/ifconfig | awk '/Link.* HWaddr/{print $1}' > /tmp/devicelist
cat /tmp/devicelist | while read dev
do
if grep -q NM_CONTROLLED /etc/sysconfig/network-scripts/ifcfg-$dev; then
    sed -r -i 's/NM_CONTROLLED=*$/NM_CONTROLLED=no/' /etc/sysconfig/network-scripts/ifcfg-$dev
    test $? -eq 0 && echo "changed ***"
else
    echo "NM_CONTROLLED=no" >> /etc/sysconfig/network-scripts/ifcfg-$dev
    test $? -eq 0 && echo "updated ***"
fi
done
rm -f /tmp/devicelist
EOF

config_resolv() {
    echo -e "nameserver 114.114.114.114\nnameserver 223.5.5.5\nnameserver 223.6.6.6" >> /etc/resolv.conf
    bash /tmp/netstop.sh
    rm -f /tmp/netstop.sh
}

#
# No plain-text password of critical users shall be stored in filesystem.
# Account 'idc' is for the use of the IDC,its password is not a secret.
# Other users shall be able to set his password without knowing the initial
# one. An administrator authenticates himself by public key.
#
config_user() {
    local sudoFile='/etc/sudoers'
    local reset_passwd='/usr/sbin/reset_passwd'
    local pubkey_url="http://$file_server/admin_pubkeys.tar.bz2"
    local admins idc_user idc_pass user sshDir authFile pubkey_pkg pubkey_dir
    idc_user='idc'
    idc_pass='06>injEXk'
    admins='payne mayu'

    # add a user for the IDC man
    useradd $idc_user
    echo "$idc_pass" | passwd --stdin $idc_user &> /dev/null
    echo "$idc_user ALL=(root) /sbin/service, /sbin/shutdown, /sbin/reboot"  >> "$sudoFile"

    # retrieve and extract the public keys
    pubkey_dir="$baseDir/pubkeys"
    pubkey_pkg="$baseDir/pubkeys.tar.bz2"
    mkdir -p "$pubkey_dir"
    wget -q "$pubkey_url" -O "$pubkey_pkg"
    tar --strip-components=1 -xjf "$pubkey_pkg" -C $pubkey_dir || return 1

    # add accounts for the administrators
    for user in $admins
    do
        useradd $user

        echo "$user  ALL=(root)   ALL" >> "$sudoFile"
        echo "#reset-password-start-$user" >> "$sudoFile"
        echo "$user  ALL=(root)   NOPASSWD: $reset_passwd" >> "$sudoFile"
        echo "#reset-password-end-$user" >> "$sudoFile"

        sshDir="/home/$user/.ssh"
        authFile="$sshDir/authorized_keys"
        mkdir -p "$sshDir"
        cp -f "$pubkey_dir/$user" "$authFile"
        chmod 755 "$sshDir"
        chmod 644 "$authFile"
    done

cat > "$reset_passwd" <<'EOF'
#!/bin/bash
#
# Author:   Joshua Chen <iesugrace@gmail.com>
# Date:     2016-06-14 13:06:20
# Location: Shenzhen
# Desc:     Run as root to reset user's password,
#           intended to run by sudo only.
#
test -z "$SUDO_USER" && { echo "not called by sudo"; exit 1; }
user=$SUDO_USER
sudoFile="/etc/sudoers"

start="^#reset-password-start-$user"
end="^#reset-password-end-$user"
if sed -r -n "/$start/,/$end/p" "$sudoFile" | grep -q $0; then
    passwd $user
    if test $? -eq 0; then
        sed -r -i "/$start/,/$end/d" "$sudoFile"
    fi
else
    echo "not allowed to reset password" >&2
fi
EOF

chmod 755 $reset_passwd
}

config_monitor() {
    local zbx_url="http://$file_server/zabbix-2.2.2.tar.gz"
    local zbx_etc='/etc/zabbix'
    local zbx_log='/var/log/zabbix'
    local zbx_agentd='/etc/init.d/zabbix_agentd'
    local zbx_scripts='/etc/zabbix/zabbix_agentd.conf.d'
    local zbx_agentd_conf='/etc/zabbix/zabbix_agentd.conf'
    local zbx_user=zabbix
    local zbx_uid=201
    local zbx_shell='/sbin/nologin'
    local zbx_server='114.119.10.166,43.241.11.44'

    #
    # install Zabbix
    #
    ncpu=$(grep -c processor /proc/cpuinfo)
    yum -y install gcc gcc-c++ make || return 1

    groupadd $zbx_user -g $zbx_uid
    useradd -g $zbx_user -u $zbx_uid -s $zbx_shell -m $zbx_user
    wget -q "$zbx_url" -O- | tar xzf - -C $baseDir || return 1
    cd $baseDir/zabbix-2.2.2
    ./configure --prefix=/usr/local/zabbix \
                --sysconfdir=/etc/zabbix \
                --enable-agent && \
    make -j $ncpu && make install

    test ! -d "$zbx_etc" && return 1
    mkdir "$zbx_log"
    chown zabbix.zabbix "$zbx_log"
    cp misc/init.d/fedora/core/zabbix_agentd "$zbx_agentd"
    chmod 755 "$zbx_agentd"
    sed -i "s#BASEDIR=/usr/local#BASEDIR=/usr/local/zabbix#g" "$zbx_agentd"
    find /usr/local/zabbix/bin/  -type f | xargs ln -s -t /usr/bin
    find /usr/local/zabbix/sbin/ -type f | xargs ln -s -t /usr/sbin

    wget -P $zbx_scripts http://$file_server/nginx_error.sh
    wget -P $zbx_scripts http://$file_server/diskscan.sh
    wget -P $zbx_scripts http://$file_server/disk_space.sh
    chmod 755 $zbx_scripts/*.sh

    sed -r -i \
        -e "s/Server=127.0.0.1/Server=$zbx_server/g" \
        -e "s#tmp/zabbix_agentd.log#var/log/zabbix/zabbix_agentd.log#g" \
        -e "\#UnsafeUserParameters=0#aUnsafeUserParameters=1" \
        "$zbx_agentd_conf"
cat >> "$zbx_agentd_conf" <<'EOF'
UserParameter=error.diskscan[*],/etc/zabbix/zabbix_agentd.conf.d/diskscan.sh
UserParameter=nginx_error,/etc/zabbix/zabbix_agentd.conf.d/nginx_error.sh
UserParameter=disk_space,/etc/zabbix/zabbix_agentd.conf.d/disk_space.sh
EOF
    chmod 777 /tmp
    $zbx_agentd start
    chkconfig --level 2345 zabbix_agentd on
    lsof -i:10050 || return 1

    #
    # install SNMP
    #
    local snmp_conf='/etc/snmp/snmpd.conf'
    yum groupinstall "SNMP Support" -y || return 1
    test -f "$snmp_conf" || return 1
    sed -r -i \
        -e '/notConfigUser/s/default/114.119.10.174/' \
        -e '/com2sec notConfigUser/acom2sec notConfigUser 43.241.11.35 speedtop' \
        -e '/notConfigUser/s/public/speedtop/' \
        -e '/notConfigGroup/s/systemview/all/' \
        -e '/view all/s/#//' \
    "$snmp_conf"
    /etc/init.d/snmpd start
    chkconfig --level 2345 snmpd on
    pgrep snmpd || return 1
}

config_kernel_params() {
local sysctl_conf='/etc/sysctl.conf'
local limit_conf='/etc/security/limits.conf'
local nofile=655350
cat >> "$sysctl_conf" <<'EOF'
fs.file-max = 5000000
vm.zone_reclaim_mode = 1
kernel.pid_max = 4194303
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_synack_retries = 2
net.ipv4.conf.lo.arp_announce=2
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1800
EOF
sysctl -p || return 1

cat >> "$limit_conf" <<EOF
* soft nofile $nofile
* hard nofile $nofile
EOF
}

config_cmd_hist() {
cat >> /etc/bashrc <<EOF
# aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ls='ls --color=auto'
alias ll='ls -l'
alias l='ll -trh'

HISTSIZE=1000000
HISTFILESIZE=2000000
HISTTIMEFORMAT='[%Y-%m-%d %H:%M:%S] '

#export EDITOR=vi
EOF
}

config_selinux() {
    sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config
}

config_iptables() {
    /etc/init.d/iptables stop
    chkconfig iptables --level 2345 off
}

config_sshd() {
    local conf='/etc/ssh/sshd_config'
    sed -r -i \
        -e '/GSSAPIAuthentication/s/yes/no/' \
        -e '/GSSAPICleanupCredentials/s/yes/no/' \
        -e '/UseDNS/s/^#//' \
        -e '/UseDNS/s/yes/no/' \
        "$conf"
        echo "Port 9089" >> "$conf"
        echo "DenyUsers idc" >> "$conf"
}

config_wget2() {
    local url="http://$file_server/wget2.tar.gz"
    wget -q "$url" -O- | tar xzf - -C /usr/local
    ln -s /usr/local/wget2/bin/wget /usr/sbin/wget2
}

config_wget3() {
    local url="http://$file_server/wget3"
    local url2="http://$file_server/dist_doit.sh"
    local url3="http://$file_server/pingOne.sh"
    wget -q "$url" -O /usr/bin/wget3
    wget -q "$url2" -O /root/scripts/dist_doit.sh
    wget -q "$url3" -O /root/scripts/pingOne.sh
    chmod 755 /usr/bin/wget3 /root/scripts/dist_doit.sh /root/scripts/pingOne.sh
}

config_ipgabc() {
    local url="http://$file_server/ipgabc"
    wget -q "$url" -O /etc/nginx/
    chmod 755 /etc/nginx/ipgabc
    /etc/nginx/ipgabc 127.0.0.1:7788 "http://drms.powerleadercdn.com/fcgi?$HOSTNAME#http://drms2.powerleadercdn.com/fcgi?$HOSTNAME"
    echo '/etc/nginx/ipgabc 127.0.0.1:7788 http://drms.powerleadercdn.com/fcgi?$HOSTNAME#http://drms2.powerleadercdn.com/fcgi?$HOSTNAME' >> /etc/rc.local
}

install_nginx() {
    local ip=$1
    local user=nginx
    local cacheDir='/data/cache1'
    local url="http://$file_server/nginx-20160803-1.4.7.1-1.el6.x86_64.rpm"
    local nginx_pkg="$baseDir/nginx.rpm"
    mkdir /data/vhost
    groupadd $user && useradd -g $user $user || return 1
    yum install openssl -y
    mkdir -p /data/cache1/{data,temp} && chown -R $user.$user $cacheDir/*
    wget -q "$url" -O "$nginx_pkg"
    rpm -i $nginx_pkg
    rpm -q nginx || return 1
    sed -r -i '/cache2/d' /etc/nginx/webconf.d/http_disks.conf
    sed -r -i '/cache/s/^/#/' /etc/nginx/sysconf.d/server_customer_log.conf
    sed -r -i '/log_format cache/s/^/#/' /etc/nginx/sysconf.d/http_customer_log.conf
    sed -r -i "/bind/s/[1-9]+.*/$ip;/" /etc/nginx/node.conf
    sed -r -i '/mhost/s/ops.powerleadercdn.com/drms.powerleadercdn.com/' /etc/nginx/node.conf
    echo "/usr/sbin/nginx" >> /etc/rc.local
    chkconfig nginx on
    # start the service
    /usr/sbin/nginx
}

install_srs() {
    local url="http://$file_server/srs.tar.gz"
    wget -q "$url" -O- | tar xzf - -C /opt
}


config_vim() {
    local url="http://$file_server/vimrc"
    wget -q "$url" -O- >> /etc/vimrc
}

config_analyzer() {
    local analysis_pkg_url="http://$file_server/fenxi2.tar.gz"
    local cronFile='/var/spool/cron/root'
    wget -q "$analysis_pkg_url" -O- | tar xzf - -C /opt
    echo "#*/5 * * * * /opt/fenxi2/tar_analyzer.sh" >> "$cronFile"
}

config_compress() {
    local compress_pkg_url="http://$file_server/old_as.tar.gz"
    local cronFile='/var/spool/cron/root'
    wget -q "$compress_pkg_url" -O- | tar xzf - -C /data
    mkdir -p /data/old_as/complog
    echo "0 2 * * *   /data/old_as/compressor.sh" >> "$cronFile"
}
config_ngctool() {
    local url="http://$file_server/ngctool"
    local cronFile='/var/spool/cron/root'
    local prog='/usr/bin/ngctool'
    wget http://$file_server/ngctool -O "$prog" || return 1
    wget http://$file_server/ngctool3 -O /usr/bin/ngctool3
    wget http://$file_server/xdelta3 -O /usr/local/bin/xdelta3
    chmod 755 "$prog"
    chmod 755 /usr/local/bin/xdelta3
    chmod 755 /usr/bin/ngctool3
    echo '0 */1 * * * flock -xn /tmp/ngctool.lock -c "ngctool rml: > /dev/shm/cached.list.bak && mv /dev/shm/cached.list{.bak,}"' >> "$cronFile"
}

config_nginx_error_monitor() {
    local url="http://$file_server/nginx_error_log.sh"
    local cronFile='/var/spool/cron/root'
    mkdir /root/scripts
    wget -q "$url" -P /root/scripts/
    chmod 755 /root/scripts/nginx_error_log.sh
    echo "*/5 * * * * /root/scripts/nginx_error_log.sh" >> $cronFile
}

config_srs_monitor() {
    local url="http://$file_server/srs_monitor.sh"
    local cronFile='/var/spool/cron/root'
    mkdir /root/scripts
    wget -q "$url" -P /root/scripts/
    chmod 755 /root/scripts/srs_monitor.sh
    echo "#*/5 * * * * /root/scripts/srs_monitor.sh" >> $cronFile
}

config_nginx_error_wechat() {
    local url="http://$file_server/nginx_error_wechat.sh"
    local cronFile='/var/spool/cron/root'
    wget -q "$url" -O /root/scripts/nginx_error_wechat.sh
    chmod 755 /root/scripts/nginx_error_wechat.sh
    echo '*/5 * * * * flock -xn /var/run/nginx-error-wechat.lock -c "bash /root/scripts/nginx_error_wechat.sh &>/dev/null"' >> $cronFile
}    

config_config_updater() {
    local updater='/usr/sbin/nginx_config_updater.sh'
    local cronFile='/var/spool/cron/root'
    wget http://$file_server/nginx_config_updater.sh -O- > $updater
    chmod 755 $updater
    echo "* * * * *   $updater" >> "$cronFile"
}

config_source_site_check() {
    local updater='/root/scripts/source_site_check.sh'
    local cronFile='/var/spool/cron/root'
    wget http://$file_server/source_site_check.sh -O- > $updater
    chmod 755 $updater
    echo "*/5 * * * * bash $updater &>/dev/null" >> "$cronFile"
}

config_http_respones_monitor() {
    local updater='/root/scripts/http_respones_monitor.sh'
    local cronFile='/var/spool/cron/root'
    wget http://$file_server/http_respones_monitor.sh -O- > $updater
    chmod 755 $updater
    echo "*/4 * * * * bash $updater &>/dev/null" >> "$cronFile"
}

config_access_plcdn() {
    local updater='/root/scripts/plcdn.sh'
    local cronFile='/var/spool/cron/root'
    wget http://$file_server/plcdn.sh -O- > $updater
    chmod 755 $updater
    echo "* 8-21/1 * * * bash $updater &>/dev/null" >> "$cronFile"
}

config_node_information() {
    local updater='/root/scripts/node_information.sh '
    local cronFile='/var/spool/cron/root'
    wget http://$file_server/node_information.sh  -O- > $updater
    chmod 755 $updater
    echo "* 8-21/1 * * * bash $updater &>/dev/null" >> "$cronFile"
}

config_cleanup() {
    local cronFile='/var/spool/cron/root'
    wget http://$file_server/cleanup.sh -O- > /root/scripts/cleanup.sh
    chmod 755 /root/scripts/cleanup.sh
    echo "* 5 * * * bash /root/scripts/cleanup.sh &>>/dev/null" >> "$cronFile"
}

config_cronjob() {
    rm -f /etc/cron.d/nc-customer-all
    rm -f /etc/cron.d/nc-sys-all
}

config_logrotate() {
    local url="http://$file_server/nginx_logrotate.conf"
    wget -q "$url" -O- > /etc/logrotate.d/nginx
}

config_rsyncd() {
    local url="http://$file_server/rsyncd.conf"
    wget -q "$url" -O- > /etc/rsyncd.conf
    echo "rsync --daemon" >> /etc/rc.local
    rsync --daemon
}

install_ifbd() {
    local dir="/lib/modules/$(uname -r)"
    local url="http://$file_server/ifbd.ko"
    local dst="$dir/ifbd.ko"
    wget -q "$url" -O- > "$dst" || return 1
    /sbin/insmod "$dst" || return 1
    cat /proc/ifbd/*
    hosttag=${hostname:0:3}
    if test "$hosttag" == "MIX" -o "$hosttag" == "DOW"; then
        echo '*/5 * * * * cat /proc/ifbd/* &>/dev/null || /sbin/insmod /lib/modules/$(uname -r)/ifbd.ko' >> /var/spool/cron/root
    fi
}

install_ansible_keys() {
    local url="http://$file_server/ansible_pubkeys.tar.bz2"
    local srcDir="$baseDir/ansible"
    local dstDir="/root/.ssh"
    local authFile="$dstDir/authorized_keys"
    mkdir -p "$srcDir" "$dstDir"
    wget -q "$url" -O- | tar --strip-components=1 -xjf - -C "$srcDir"
    cat $srcDir/* >> "$authFile" || return 1
    chmod 755 "$dstDir"
    chmod 644 "$authFile"
}

show_info() {
local ip=$1 next_step="/root/next_steps"
cat > $next_step <<EOF
1. Config my.down servers:
    1. login to each of the my.down servers, switch to user 'httpd'
        # sudo -u nginx ssh -p9089 root@$ip
2. add host $ip to rsync allow list of the log server
    1. login to each of the log servers
    2. edit file /etc/rsyncd.conf
    3. stop the existing rsync daemon
        # netstat -tlpn | grep :873     <-- find the pid
        # kill <pid>
    4. start the daemon
        # rsync --daemon
3. add host $ip to DRMS
4. add host $ip to Zabbix
5. add host $ip to Cacti
6. to drms use user apache ssh login root@$ip
7. to mydown use user nginx ssh login root@$ip
8. update nignx config 
    1. wget -P /root/ http://14.152.50.38:8755/nginx_conf/new_nginx.tar.gz
    2. mv /etc/nginx{,.170216} && tar xf /root/new_nginx.tar.gz -C /etc/
    3. rm -rf /etc/nginx/webconf.d && cp -a /etc/nginx.170216/webconf.d /etc/nginx/
    4. scp -a root@58.20.31.163:/etc/nginx/conf.d /etc/nginx/
    5. /usr/sbin/nginx -t
    6. /etc/init.d/nginx restart
EOF
cat <<EOF
All done on the node, please reboot the system to apply changes.
And finish the tasks described in file $next_step to complete the setup:
EOF
cat $next_step
}

if test $# -ne 2; then
    echo "Usege: $(basename $0) HOSTNAME IP" >&2
    exit 1
fi

hostname=$1
ip=$2

if test -z "$hostname"; then
    echo "host name can not be empty" >&2
    exit 1
fi
if ! grep -qE "^([0-9]{1,3}\.){3}[0-9]{1,3}$" <<< "$ip"; then
    echo "ip $2 is invalid" >&2
    exit 1
fi

file_server='14.152.50.38:8755'
VERBOSE=1
RED_COLOR='\E[1;31m'
RES='\E[0m'
baseDir=$(mktemp -d)
trap clean_up exit
perform install_wget
begin_info
perform setHostName "$hostname"
perform install_163_repo
perform install_common_tools
perform install_prebuilt_tools
perform config_time_sync
perform config_resolv
perform config_user
perform config_monitor
perform config_kernel_params
perform config_cmd_hist
perform config_selinux
perform config_iptables
perform config_sshd
perform config_wget2
perform config_wget3
perform install_nginx "$ip"
perform install_srs
perform config_ipgabc
perform config_vim
perform config_analyzer
perform config_compress
perform config_ngctool
perform config_nginx_error_monitor
perform config_srs_monitor
perform config_nginx_error_wechat
perform config_config_updater
perform config_source_site_check
perform config_http_respones_monitor
perform config_access_plcdn
perform config_node_information 
perform config_cleanup
perform config_cronjob
perform config_logrotate
perform config_rsyncd
perform install_ifbd
perform install_ansible_keys
show_info "$ip"
