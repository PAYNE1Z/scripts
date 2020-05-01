#!/bin/bash

# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2018-05-30 11:53:53
# Location: DongGuang
# Desc:     创建或删除一个filebeat实例
#           (用于收集不用类型的日志输出到不同的kafka集群)
#

Usage() {
    echo "Usage: $0 create|delete|conf multi_num(新建或删除或要新增配置的实例编号[1-9]) [server_name]"
    exit 1
}

action_type=$1
multi_num=$2
server_name=$3
service_name=filebeat$multi_num
old_bin_dir=/usr/share/filebeat
new_bin_dir=/usr/share/filebeat$multi_num

old_conf_dir=/etc/filebeat
new_conf_dir=/etc/filebeat$multi_num
new_conf_file=$new_conf_dir/filebeat${multi_num}.yml

old_init_sh=/usr/lib/systemd/system/filebeat.service
new_init_sh=/usr/lib/systemd/system/filebeat${multi_num}.service
link_init_dir=/etc/systemd/system/multi-user.target.wants/


Create() {
    cp -r $old_bin_dir $new_bin_dir
    mv $new_bin_dir/bin/filebeat{,$multi_num}
    mv $new_bin_dir/bin/filebeat{,$multi_num}-god
    
    cp -r $old_conf_dir $new_conf_dir
    mv $new_conf_dir/filebeat.yml $new_conf_file
    
cat > $new_conf_file <<EOF
output.kafka:
  enabled: true
  hosts: ["172.16.7.35:9092","172.16.7.34:9092","172.16.7.33:9092","172.16.7.32:9092"]
  topic: '%{[type]}'

# documet_type 为 log-cg 的日志需要输出到上面这组kafka集群
filebeat.prospectors:
#------------------------------ Log prospector --------------------------------
- paths:
    - /data/logs/$server_name/cg-logs/server*.log
  fields:
    app_id: $server_name
  multiline.pattern: '^[0-9]{4}-[0-9]{2}-[0-9]{2}\s(20|21|22|23|[0-1]\d):[0-5]\d:[0-5]\d\.'
  multiline.negate: true
  multiline.match: after
  document_type: log-cg
EOF
    cp $old_init_sh $new_init_sh
    sed -i "s/filebeat/filebeat$multi_num/g" $new_init_sh
    ln -sf $new_init_sh $link_init_dir
    systemctl daemon-reload
    systemctl enable $service_name
    systemctl start $service_name
}

Delete() {
    systemctl stop $service_name
    systemctl disable $service_name
    rm -rf $new_conf_dir
    rm -rf $new_bin_dir
    rm -rf $new_init_sh
    rm -f $link_init_dir/filebeat${multi_num}.service
    systemctl daemon-reload
}

AddConf() {
cat >> $new_conf_file <<EOF

- paths:
    - /data/logs/$server_name/cg-logs/server*.log
  fields:
    app_id: $server_name
  multiline.pattern: '^[0-9]{4}-[0-9]{2}-[0-9]{2}\s(20|21|22|23|[0-1]\d):[0-5]\d:[0-5]\d\.'
  multiline.negate: true
  multiline.match: after
  document_type: log-cg
EOF
    systemctl restart $service_name
}

CheckService() {
    if test $(ps -ef|grep $service_name |grep -v grep|wc -l) -ne 0; then
	    echo "$service_name restart successfull"
		return 0
	else
	    echo "$service_name restart faild"
		return 1
	fi
}

test $# -ne 2 && Usage

case $action_type in
    create)
        if test -f $new_init_sh; then
            echo "filebeat$multi_num already existed, please check it or retry multi_num."
			exit 1
		fi
        Create
		if CheckService; then
			echo "filebeat$multi_num create successfull"
			echo "filebeat$multi_num conf file is $new_conf_file"
			echo "run cmd: systectl start filebeat$multi_num"
		fi
        ;;
    delete)
        Delete
        echo "filebeat$multi_num delete successfull"
        ;;
	conf)
	    if test "x$server_name" == "x"; then
		    echo "add conf must server_name argument, retry!"
			exit 1
		fi
	    AddConf
		if CheckService; then
		    echo "server $server_name log-cg conf into $new_conf_file successfull"
		fi
		;;
    *)
        Usage
esac
