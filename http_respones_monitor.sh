#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-05-16 16:35:17
# Location: Shenzhen
# Desc:     check node local http respones time
#

cleanUp() {
    rm -f $resultFile
}

report() {
    local groupName apiUrl msg
    #groupName="PLCDN-SUPPORT"
    groupName="PLCDN-STATUS"
    apiUrl="http://push.plcdn.net:7890/20160128"
    msg=$1
    wget -q --tries=1 --timeout=30 --header="To: $groupName" \
         --post-data="$msg" "$apiUrl" \
         -O /dev/null
}

getFlow() {
    cat /proc/net/dev | \
    awk 'NR > 2 {i=i+$2;o=o+$10;ies=iers+$4;ids=ids+$5;oes=oes+$12;ods=ods+$13} \
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
    echo -e "RateIN: ${rateIn}M ErrINs:$errIn DropINs:$dropIn\n\
RateOUT: ${rateOut}M ErrOUTs:$errOut DropOUTs:$dropOut" 
}

# 设置变量信息
checkUrl=http://dltest.borncloud.net/test.jpg
resultFile=$(mktemp)
localIp=$(awk '/bind/{print $2}' /etc/nginx/node.conf | tr -d ';')

# 记录请求测试开始时间
startTime=$(date +%s)
# 获取流量数据的起始值,将值定义为数组
flowStart=$(getFlow)
# 为了让带宽数据更准确，需要获取更长时间的流量数据来取来平均值
sleep 10

# 请求测试开始
curl --retry 3 -m 10 -I -w '@/etc/curl-fm' $checkUrl -x 127.0.0.1:80 2>/dev/null | \
grep -E "^status|P.*CDN|^time" > $resultFile
res=$?

# 获取请求命中状态、请求总时长
hitSta=$(awk '/P.*CDN/{print $2}' $resultFile | xargs)
sed -r -i "s/P.*.* * * */hitsta: $hitSta/" $resultFile
respTime=$(awk '/time_total/{print $2}' $resultFile)
test ! -s $resultFile -o -z "$hitSta" && echo "request timeout" > $resultFile

# 获取cup负载信息、运行时长
cpuAvg=$(w | awk '/average/{print $(NF-2)}'|tr -d ',')
upTime=$(w | awk -F, '/load average/{print $1}' | awk '{$1=$2=""}1' | sed -r 's/^\s+//')
cpuInfo=$(/usr/sbin/dmidecode |grep -i cpu | awk '/Version:/{print}' | column -t | head -1)
grep -qE "min|days" <<<$upTime || upTime="$upTime hous"
echo -e "###### SystemLoadInfo:\nCpuLoadAvg: $cpuAvg" >> $resultFile
echo "Uptime: $upTime" >> $resultFile

# 判断是新机器还是旧机器，并获取OS与NGINX版本信息
grep -qE "E5-2609 v3 @ 1.90GHz" <<<$cpuInfo &&  machineType="New machine" || machineType="Old machine"
osVer=$(cat /etc/redhat-release)
nginxVer=$(/usr/sbin/nginx -v 2>&1 | awk '{print $NF}')
echo -e "MachineType: $machineType \nOS: $osVer \nnginxVer: $nginxVer" >> $resultFile

# 获取系统各类负载（io sys user..)
mpstat 1 3 | sed -r -e 's/Linux.*.*(\([0-9].*CPU\)$)/CPUs: \1/' -e 's/[AP]M//' | \
awk '/CPU|Average/{print $1,$2,$3,$4,$5,$6}' >> $resultFile
free -m | awk '/Mem/{print "MEM: Total: "$2,"Free: "$4}' >> $resultFile

# 统计当前nginx连接数与运行进程数
nginxConNum=$(netstat -tunp | grep nginx | wc -l)
echo "ngxConNum: $nginxConNum" >> $resultFile
echo "ngxProcessNum: $(pgrep nginx | wc -l)" >> $resultFile

# 记录结束时间 
sleep 5
endTime=$(date +%s)
# 调用 getFlow 获取流量数据结束值
flowEnd=$(getFlow)
# 调用 calRate 计算开始到结束时间内的带宽数据
calRate "$startTime" "$endTime" "$flowStart" "$flowEnd" >> $resultFile

# 生成推送消息格式
msg=$(echo -e "##### Http Response Timeout\n \
Details: \n$(cat $resultFile)\n \
From: $localIp \n Time: $(date '+%Y-%m-%d %H:%M:%S')")

#msg="# Http Response Timeout\n--------------------\nDetails:\n$(cat $resultFile|tr '\n' '#' | sed -r -e 's/#/\\n/g' -e 's/%//g')\n--------------------\nFrom: $localIp\nTime: $(date '+%Y-%m-%d %H:%M:%S')"

# 判断请求测试结果，对超过2秒的请求推送到微信
if test $res -eq 0; then
    # 这里用到一个非常有意思的浮点数对比判断, test本身不支持浮点数的大小比较
    # 这里用到bc命令来实现,意思是传给bc的公式成立则返回1,所以这里判断bc的返回值是否等于1即可
    if test $(echo "$respTime >= 2"|bc 2>/dev/null) -eq 1; then
        # report_api : mattermost 消息推送接口 $1:msg $2:groupname [1:status|2:support|3:domain_added]
        # report_api "$msg" 1
        report "$msg"
    fi
elif test $res -eq 255; then
    #report_api "$msg" 1
    report "$msg"
fi

# 清理临时文件
trap cleanUp exit
