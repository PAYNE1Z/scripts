#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: initialization.sh                                #
# ScriptsPath:/root/shell/down_initialization.sh                #
# Purpose: initialization installed down-node system            #
# Edition: 1.1                                                  #
# CreateDate:2016-04-12 13:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

yum install wget -y &> /dev/null
wget -P /tmp/ http://14.152.50.38:8755/nginx-1.4.7.1-1.el6.x86_64.rpm &> /dev/null
wget -P /tmp/ http://14.152.50.38:8755/zabbix-2.2.2.tar.gz &> /dev/null
wget -P /tmp/ http://14.152.50.38:8755/wget2.tar.gz &> /dev/null


HOSTNAME=$1
IP=$2

read -p "运行此脚本前，请确认在/tmp目录下有 zabbix 和 wget2 nginx 的软件包:确认请按 y " yes
if [ $yes == y ]; then
if [ -f /tmp/zabbix-2.2.2.tar.gz -a -f /tmp/wget2.tar.gz -a -f /tmp/nginx-1.4.7.1-1.el6.x86_64.rpm ]; then


sed -i "s/HOSTNAME=.*/HOSTNAME=$HOSTNAME/" /etc/sysconfig/network
if [ $? -eq 0 ];then
    echo "change host name success @_@ "
else
    echo "change host name fail !!!!"
    exit 0
fi

echo "#======== Install 163yum source =======#"

#yum install wget -y &> /dev/null

if [ ! -f /etc/yum.repos.d/CentOS6-Base-163.repo ]; then
    cd /etc/yum.repos.d/
    wget http://mirrors.163.com/.help/CentOS6-Base-163.repo &> /dev/null
    yum makecache &> /dev/null
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
    yum repolist &> /dev/null

    if [ $? -eq 0 ];then
        echo "163 yum source install success @_@ "
    else
        echo "163 yum source install fail !!!!"
        exit 1
    fi
fi
cd


echo "#========== Install common software =========#"

yum install rsync dmidecode unzip iptraf git initscripts shadow-utils dnsmasq logrotate tree vixie-cron screen bc sysstat man vim lrzsz lsof tcpdump telnet nc -y &> /dev/null
if [ $? -eq 0 ];then
    echo "common software installed success @_@ "
else
    exit 2
fi

echo "#==== Synchronous configuration and public network time server ===#"

yum install ntp -y &> /dev/null
if [ -f /etc/ntp.conf ];then
    echo "server 0.asia.pool.ntp.org" >> /etc/ntp.conf
    echo "server 1.asia.pool.ntp.org" >> /etc/ntp.conf
    echo "server 2.asia.pool.ntp.org" >> /etc/ntp.conf
    echo "server 3.asia.pool.ntp.org" >> /etc/ntp.conf
fi
/etc/init.d/ntpdate start &> /dev/null
/etc/init.d/ntpd start &> /dev/null
chkconfig --level 2345 ntpd on

if [ $? -eq 0 ];then
    echo "synchronous configuration success @_@ "
else
    exit 3
fi

echo "#============ Configuration sudo ==============#"

useradd joshua && useradd payne && useradd idc
tr -dc _A-Z-a-z-0-9 < /dev/urandom | fold -w 8 | head -3 >> /root/.password.txt
head -1 /root/.password.txt | passwd --stdin joshua &> /dev/null
head -2 /root/.password.txt | tail -1 | passwd --stdin payne &> /dev/null
tail -1 /root/.password.txt | passwd --stdin idc &> /dev/null

USERS=$(grep -E "payne|joshua|idc" /etc/passwd | wc -l)
if [ $USERS -eq 3 ];then
    echo -e "idc\tALL= /etc/init.d/network, /sbin/shutdown, /sbin/reboot" >> /etc/sudoers
    echo -e "joshua\tALL=(ALL)\tALL" >> /etc/sudoers
    echo -e "payne\tALL=(ALL)\tALL" >> /etc/sudoers
fi

QX=$(grep -E "payne|joshua|idc" /etc/sudoers | wc -l)
if [ $QX -eq 3 ];then
    echo "configuration sudo success @_@ "
else
    exit 4
fi

echo "#=========== Install agent ZABBIX =============#"

#wget http://114.119.10.171/zabbix-2.2.2.tar.gz &> /dev/null
#[ $? -eq 0 ] && echo "zabbix download success @_@" || exit 5

yum -y install gcc gcc-c++ make &> /dev/null

if [ $? -eq 0 ];then
    groupadd zabbix -g 201
    useradd -g zabbix -u 201 -s /sbin/nologin -m zabbix
    cd /tmp/
    tar xf zabbix-2.2.2.tar.gz
    cd zabbix-2.2.2
    ./configure --prefix=/usr/local/zabbix --sysconfdir=/etc/zabbix --enable-agent &> /dev/null
    make &> /dev/null && make install &> /dev/null
fi

if [ -d /etc/zabbix ];then
    mkdir /var/log/zabbix
    chown zabbix.zabbix /var/log/zabbix/
    cp misc/init.d/fedora/core/zabbix_agentd /etc/init.d/
    chmod 755 /etc/init.d/zabbix_agentd
    sed -i "s#BASEDIR=/usr/local#BASEDIR=/usr/local/zabbix#g" /etc/init.d/zabbix_agentd
    ln -s /usr/local/zabbix/bin/* /usr/bin/
    ln -s /usr/local/zabbix/sbin/* /usr/sbin/
    wget -P /etc/zabbix/zabbix_agentd.conf.d/ http://14.152.50.38:8755/nginx_error.sh &> /dev/null
    wget -P /etc/zabbix/zabbix_agentd.conf.d/ http://14.152.50.38:8755/diskscan.sh &> /dev/null
    wget -P /etc/zabbix/zabbix_agentd.conf.d/ http://14.152.50.38:8755/disk_space.sh &> /dev/null
    chmod 755 /etc/zabbix/zabbix_agentd.conf.d/*.sh
    sed -i "s/Server\=127.0.0.1/Server\=127.0.0.1,114.119.10.166/g" /etc/zabbix/zabbix_agentd.conf
    sed -i "s#tmp/zabbix_agentd.log#var/log/zabbix/zabbix_agentd.log#g" /etc/zabbix/zabbix_agentd.conf
    sed -i "\#UnsafeUserParameters=0#aUnsafeUserParameters=1\n" /etc/zabbix/zabbix_agentd.conf
    echo "UserParameter=error.diskscan[*],/etc/zabbix/zabbix_agentd.conf.d/diskscan.sh" >> /etc/zabbix/zabbix_agentd.conf
    echo "UserParameter=nginx_error,/etc/zabbix/zabbix_agentd.conf.d/nginx_error.sh" >> /etc/zabbix/zabbix_agentd.conf
    echo "UserParameter=disk_space,/etc/zabbix/zabbix_agentd.conf.d/disk_space.sh" >> /etc/zabbix/zabbix_agentd.conf
    /etc/init.d/zabbix_agentd start &> /dev/null
    chkconfig --level 2345 zabbix_agentd on
else
    echo "zabbix agent install fail x_x"
    exit 6
fi

lsof -i:10050 &> /dev/null
[ $? -eq 0 ] && echo "zabbix agent installed success @_@ "

echo "#============ Install cacti client ===============#"

yum groupinstall "SNMP Support" -y &> /dev/null

[ $? -eq 0 ] && echo "cacti snmp installed success @_@ " || exit 7

echo "#============ Configuration SNMP =================#"

if [ -f /etc/snmp/snmpd.conf ];then
    sed -i '/notConfigUser/s/default/114.119.10.174/' /etc/snmp/snmpd.conf
    sed -i '/notConfigUser/s/public/speedtop/' /etc/snmp/snmpd.conf
    sed -i '/notConfigGroup/s/systemview/all/' /etc/snmp/snmpd.conf
    sed -i '/view all/s/#//' /etc/snmp/snmpd.conf
    echo "Port 9089" >> /etc/ssh/sshd_config
    /etc/init.d/snmpd start &> /dev/null
    chkconfig --level 2345 snmpd on
fi

pgrep snmpd &> /dev/null
[ $? -eq 0 ] && echo "snmp configuration success @_@ " || exit 8


echo "#========== Enhance network throughput (TCP setup /etc/sysctl.conf) ============#"

echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 4096" >> /etc/sysctl.conf
echo "net.ipv4.tcp_synack_retries = 2" >> /etc/sysctl.conf
echo "net.ipv4.conf.lo.arp_announce=2" >> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_recycle = 1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_fin_timeout = 30" >> /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_time = 1800" >> /etc/sysctl.conf
sysctl -p &> /dev/null

[ $? -eq 0 ] && echo "enhance network configreation success @_@ " || exit 9

echo "#========== Modify the system limit  =========#"

echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf
[ $? -eq 0 ] && echo "set maximum number open file success @_@ " || exit 10

echo "#============== Global command history ================#"

echo "HISTSIZE=1000000" >> /etc/bashrc
echo "HISTFILESIZE=2000000" >> /etc/bashrc
echo "HISTTIMEFORMAT='[%Y-%m-%d %H:%M:%S] '" >> /etc/bashrc
[ $? -eq 0 ] && echo "set history global success @_@ " || exit 11

echo "#============= Close SELinux, iptables =================#"

sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config
/etc/init.d/iptables stop &> /dev/null
chkconfig iptables --level 2345 off
[ $? -eq 0 ] && echo "selinux iptables close success @_@ " || exit 12

echo "#=========== configuration ssh  ==========#"

sed -i '/GSSAPIAuthentication/s/yes/no/' /etc/ssh/sshd_config
sed -i '/GSSAPICleanupCredentials/s/yes/no/' /etc/ssh/sshd_config
sed -i '/UseDNS/s/^#//' /etc/ssh/sshd_config
sed -i '/UseDNS/s/yes/no/' /etc/ssh/sshd_config

[ $? -eq 0 ] && echo "configreation ssh success @_@" || exit 13


echo "#===========  install  wget2 =============#"

[ -f "/tmp/wget2.tar.gz" ] && mkdir -p /home/wget && cd /tmp && tar xf wget2.tar.gz -C /home/wget/ && ln -s /home/wget/bin/wget /usr/sbin/wget2 || exit 8
[ $? -eq 0 ] && echo "configreation ssh success @_@" || exit 8


echo "#========== install nginx(rpm) ===============#"

groupadd nginx && useradd -g nginx nginx
yum install openssl -y &> /dev/null
mkdir -p /data/cache1/{data,temp} && chown -R nginx.root /data/cache1/*
#mkdir -p /data/cache2/{data,temp} && chown -R nginx.root /data/cache2/* 
cd /tmp && rpm -ivh nginx-1.4.7.1-1.el6.x86_64.rpm && rpm -q nginx
    if [ $? -eq 0 ]; then
        sed -i '/cache2/d' /etc/nginx/webconf.d/http_disks.conf
        sed -i '/cache/s/^/#/' /etc/nginx/sysconf.d/server_customer_log.conf
        sed -i '/log_format cache/s/^/#/' /etc/nginx/sysconf.d/http_customer_log.conf
        sed -i "/bind/s/[1-9]+*.*/$IP;/" /etc/nginx/node.conf
    fi
NginxConfig=/etc/nginx/modules/mod_acl.lua
echo -e "function domain_back(p)" >> $NginxConfig
echo -e "  if cache.context_check(cache.CTX_ACTION) and p ~= \"\" then" >> $NginxConfig
echo -e "    ngx.var.mproxy_domain = p" >> $NginxConfig
echo -e "  end" >> $NginxConfig
echo -e "end" >> $NginxConfig
#20160612 12:00 add 

#/etc/init.d/nginx start
echo "/usr/sbin/nginx" >> /etc/rc.local
/usr/sbin/nginx
[ $? -eq 0 ] && echo "nginx installed success @_@" || exit 2


echo "colorscheme  desert" >> /etc/vimrc

echo "#============ scripts && crontab =========#"
wget -P /tmp/ http://14.152.50.38:8755/fenxi2.tar &> /dev/null
tar xf /tmp/fenxi2.tar -C /opt/
#mkdir /opt/shuaxin && wget -P /opt/shuaxin/ http://14.152.50.38:8755/mulushuaxin.sh &> /dev/null
#chmod 755 /opt/shuaxin/mulushuaxin.sh /opt/fenxi2/bdsc.sh
wget -P /usr/sbin/ http://14.152.50.38:8755/freecdn_sync.sh &> /dev/null
wget -P /usr/sbin/ http://14.152.50.38:8755/nginx_logrotate.sh &> /dev/null
chmod 755 /usr/sbin/freecdn_sync.sh /usr/sbin/nginx_logrotate.sh
wget -P /etc/cron.d/ http://14.152.50.38:8755/nc-customer-all &> /dev/null
wget -P /etc/cron.d/ http://14.152.50.38:8755/nc-sys-all &> /dev/null
#echo "*/2 * * * *  cd /opt/shuaxin && bash mulushuaxin.sh" >> /var/spool/cron/root
echo "*/5 * * * * /opt/fenxi2/analyzer.sh > /dev/null" >> /var/spool/cron/root
#echo "0 1 * * * find /data/count_log/ -ctime +7 -exec rm -rf {} \;  2>/dev/null" >> /var/spool/cron/root
echo "0 4 * * * ngctool 'rm:' /data/cache1/data /data/cache2/data &> /dev/null" >> /var/spool/cron/root

crontab -l
test $? -eq 0 && echo "scripts && crontab configure success@_@" || exit 1

wget -P /etc/ http://14.152.50.38:8755/rsyncd.conf &> /dev/null
rsync --daemon
echo "rsync --daemon" >> /etc/rc.local


wget -P /usr/bin/ http://14.152.50.38:8755/ngctool &> /dev/null
chmod 755 /usr/bin/ngctool
test $? -eq 0 && echo "ngctool install success@_@" || exit 1


cd /lib/modules/$(uname -r)/ 
test $? -eq 0 && wget -P /lib/modules/$(uname -r)/ http://14.152.50.38:8755/ifbd.ko &> /dev/null
test $? -eq 0 && insmod ./ifbd.ko && cat /proc/ifbd/*
test $? -eq 0 && echo "ifbd.ko installed success@_@" || exit 2


echo "#======================================================#"
echo " #========= Need to reboot the computer =============#"
echo "#======================================================#"
else
echo "/tmp dir no such zabbix wget2 nginx software" 
fi
else
exit 1
fi
