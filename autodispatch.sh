#!/bin/bash
#
# $1: admin email address
# $2: subject
# $3: message body
#

echo -e "$(date '+%Y-%m-%d %H:%M:%S')\n1: $1 \n------------------------ \n2: $2 \n ------------------------------------\n3: $3\n######################################################################\n" >> /tmp/zabbix_action.log 
bash /etc/zabbix/zabbix_server.conf.d/changeNodeState.sh "$2" "$3"
