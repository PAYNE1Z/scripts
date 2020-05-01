#!/bin/bash

serviceON=/tmp/serviceON.txt
servicefile=/tmp/chkconfig.txt

chkconfig --list | grep -vE "xinetd|.*[a-z]:+" | awk '{print $1}' > $servicefile

cat $servicefile | while read services

do

test ! -z $serviceON && grep $services $serviceON &> /dev/null
test $? -ne 0  && chkconfig $services off && echo "$services 已关闭开机自启"
#test $? -eq 0  && chkconfig $services on && echo "$services 已开启开机自启"

done
 
