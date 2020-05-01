#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2018-01-23 15:34:43
# Location: DongGuang
# Desc:     create new service conf file
#


HELP() {
    echo -e "\E[1;33mUsage: $0 PORT APP_NAME MEM_SIZE APP_JAR\E[0m"
    exit
}

wget_jar() {
    down_status=$(curl -I $DOWN_SOURCE/$APP/$APP_JAR 2>&1 | awk '/HTTP\/1.1/{print $2}')
    down_size=$(curl -I $DOWN_SOURCE/$APP/$APP_JAR 2>&1 | awk '/Content-Length:/{print $2}' | sed -r 's/[^0-9]//')
    if test "$down_status" != "200"; then
        echo -e "\E[1;31mMysrc: $DOWN_SOURCE not found $APP_JAR, please check it\E[0m"
    exit
    else
    wget -P $APP_HOME/ $DOWN_SOURCE/$APP/$APP_JAR
    test -f $APP_HOME/$APP_JAR && local_size=$(du -b $APP_HOME/$APP_JAR | awk '{print $1}')
        if test ! -z "$local_size" -a "$local_size" == "$down_size"; then
            echo -e "\E[1;32m$APP_JAR donwload successfull\E[0m"
        else
            echo -e "\E[1;31m$APP_JAR download error, please check it\E[0m"
        exit
        fi
    fi
}

make_op_file() {
cat > $APP_OP_FILE <<EOF
server.port=$PORT
spring.application.name=$APP

logging.level.root=INFO
logging.level.com.tuandai=INFO

spring.application.index=0
spring.cloud.config.profile=prev

encrypt.keyStore.location=file:///usr/local/software/td-config/tdkeys.jks
encrypt.keyStore.password=1p1eu05AXi90*x
encrypt.keyStore.alias=tdkey
encrypt.keyStore.secret=td1209*2@1Xa
EOF
    echo -e "\E[1;32m$APP_OP_FILE create successfull\E[0m"
}

make_s_file() {
cat > $APP_S_FILE <<EOF
[Unit]
Description=$APP service
After=syslog.target

[Service]
EnvironmentFile=/usr/local/software/td-config/enviroments
Type=simple
ExecStart=/usr/local/java/jdk/bin/java -server -Xms${M_SIZE}m -Xmx${M_SIZE}m -XX:+UseG1GC -verbose:gc -Xloggc:/data/logs/${APP}-gc.log -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=100M -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/data/logs -Duser.timezone=GMT+8 -jar /usr/local/software/$APP/$APP_JAR --spring.config.location=/usr/local/software/$APP/override.properties
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    echo -e "\E[1;32m$APP_S_FILE create successfull\E[0m"
}

make_install_sh() {
cat > $APP_INSTALL_SH <<EOF
#!/bin/bash
cp ${APP}.service /etc/systemd/system/
systemctl enable ${APP}.service
EOF
    echo -e "\E[1;32m$APP_INSTALL_SH create successfull\E[0m"
}

PORT=$1
APP=$2
M_SIZE=$3
APP_JAR=$4
APP_HOME="/usr/local/software/$APP"
APP_OP_FILE="$APP_HOME/override.properties"
APP_S_FILE="$APP_HOME/${APP}.service"
APP_INSTALL_SH="$APP_HOME/install.sh"
DOWN_SOURCE='http://mysrc.bujidele.com:4019/'


test $# -ne 4 && HELP
test ! -d $APP_HOME && mkdir $APP_HOME

wget_jar
make_op_file
make_s_file
make_install_sh

chmod 755 $APP_OP_FILE $APP_S_FILE $APP_INSTALL_SH

echo -e "\n\E[1;32mJob Done\E[0m"
