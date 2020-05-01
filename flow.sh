#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-06-16 09:58:20
# Location: Shenzhen
# Desc: 
#

getFlow() {
    cat /proc/net/dev | \
    awk 'NR > 2 {i=i+$2;o=o+$10;ies=iers+$3;ids=ids+$4;oes=oes+$12;ods=ods+$13} \
    END{print i,ies,ids,o,oes,ods}'
}

calRate() {
    local stratTime=$1 endTime=$2 dateS=$3 dateE=$4
    local rateIn errIn dropIn rateOut errOut dropOut rateTime
    # 流量数据值经过多次的变量替换,已经变成了单一的值。
    # 所以在这里将变量值转成数组,如果是直接定义数组就不需要于再转换
    read -a flowStart <<<$dateS
    read -a flowEnd <<<$dateE
    rateTime=$(($endTime-$stratTime))
    # 由于bc的自身原因,除法运算的值小于1时,前面的0不会显示,这里用awk进行格式化输出
    rateIn=$(echo "scale=2;(${flowEnd[0]}-${flowStart[0]})/1024/1024/${rateTime}*8"|bc|awk '{printf "%.2f\n", $0}')
    errIn=$((${flowEnd[1]}-${flowStart[1]}))
    dropIn=$((${flowEnd[2]}-${flowStart[2]}))
    rateOut=$(echo "scale=2;(${flowEnd[3]}-${flowStart[3]})/1024/1024/${rateTime}*8"|bc|awk '{printf "%.2f\n", $0}')
    errOut=$((${flowEnd[4]}-${flowStart[4]}))
    dropOut=$((${flowEnd[5]}-${flowStart[5]}))
    echo -e "RateIN:${rateIn}M ErrINs:$errIn DropIns:$dropIn\n\
RateOUT:${rateOut}M ErrOUTs:$errOut DropOUTs:$dropOut" 
}
