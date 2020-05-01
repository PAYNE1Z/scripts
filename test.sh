#!/bin/bash

xxx=$@
Test=${!#}
# ${!#} 代表脚本的最后一个参数
One=$1
Two=$2
# $1 $2 代表脚本的第一个和第二个参数
Three=$#
# $# 代表脚本后面参数的个数
Four=$*
# $* 代表脚本后面的所有参数
Five=$0
# $0 代表脚本本身
ps -ef &> /dev/null &
Six=$!
# $! 代表最后执行的后台命令的PID(注意是后台程序）
Seven="$_"
# $_ 代表上一个命令的最后一个参数
echo "$xxx is \$@"
echo "$Test is \${!#}" 
echo "$One is \$1"
echo "$Two is \$2"
echo "$Three is \$#"
echo "$Four is \$*"
echo "$Five is \$0"
echo "$Six is \$!"
test -z "$_" && echo yes || echo "\$_ is $_" 
