#!/bin/bash

#---------------------------------------------------------------#
# ScriptsName: dist_doit.sh                                     #
# ScriptsPath:/root/scripts/dist_doit.sh                        #
# Purpose: vhost distribute customer file                       #
# Edition: 3.0                                                  #
# CreateDate:2016-09-04 13:31                                   #
# Author: Payne Zheng <zzuai520@live.com>                       #
#---------------------------------------------------------------#

# Get source file to local
# -b background operation 
# --output-file=${wget_log} output to the specified file
# --max-redirect=0 maximum allowed redirection (disable redirection)
# --tries=1 maximum retry (default 20)
# --limit-rate=20m speed limit
# First take data from the upnode,  if you fail find the source station to take

tailFile() {
    local lock=$1 wget_log=$2
    if [ -f ${wget_log} ]; then
        PID=$(cat $lock)
        test -z $PID && { tail -n10 ${wget_log};exit; }
        tail -F -n5 --pid $PID ${wget_log}
        exit
    else
        sleep 0.5
        tailFile "$lock" "${wget_log}"
    fi
}

wgetOne() {
    local url="$1" pnode=$2 wget_log=$3 download_dir=$4
    local wget3=/usr/bin/wget3
    test "$suffix" == "xplcdn" -a "$level" == "2" -a "$pnode" != "$snode" && download_dir="/data/"
    # 拿差异文件在上层拿是要通过vhost的，所以在url就带有vhost,在download_dir中就不需要vhost这级目录了
    # 但当下层节点在上层拿不到时，就会回源拿，回源时的url中是不带vhost的，所有这种情况下download_dir又要带vhost这级目录
    $wget3 --header='Accept-Encoding:gzip, deflate, sdch' --max-redirect=0 \
    --progress=% -P ${download_dir} --tries=2 --timeout=30 -np -c -r \
    --limit-rate=20m "$url" -e http-proxy=$pnode:80
}

wgetSlice() {
    local user=$1 url="$2" pnode=$3 wget_log=$4 download_dir=$5 tempDownFile="$6"
    local wget3=/usr/bin/wget3 size=$7
    $wget3 --header='Accept-Encoding:gzip, deflate, sdch' --max-redirect=0 \
    --progress=%:$size -c -O ${download_dir}/"${tempDownFile}"  --tries=2 --timeout=30 \
    --limit-rate=20m "$url" -e http-proxy=$pnode:80
}


# Check downfile size
checkDown() {
    local wget_log=$1 url="$2" downFile=$3
    
    downSize=$(du -b "/data/vhost/${downFile}" | awk '{print $1}')
    if [ "$downSize" = "$size" ]; then
        echo -e "== CHECK WGET DONE ==\n100%" | tee -a ${wget_log}
        return 0
    else
        echo -e " == DOWNLOAD ERROR ==\n0%" | tee -a ${wget_log}
        rm -rf "/data/vhost/${downFile}" && exit 1
        return 1
    fi
}

checkRfile() {
    local url="$1" xdownFile="$2" domain="$3"
    xPath="${downFile%/*}"
    tempdFile="${downFile##*^}"
    dFile="$xPath/${tempdFile/.xplcdn/}"
    dFileName="${tempdFile/.xplcdn/}"
    rUrl="${url%^*}"
    localDurl="http://${xPath}/${dFileName}"
    dtext=$(ngctool "md5=$localDurl" $cccdir 2>/dev/null)
    localDmd5=${dtext:0-32}
    echo "$localDmd5"
    echo "$dtext"
    test "$localDmd5" == "$md5" && { echo -e "Dfile Cached ,Nothing to do\n100%" | tee -a ${wget_log};exit; }
    rCacheFile=$(ngctool "ls=$rUrl" $cccdir 2>/dev/null | cut -d ' ' -f1)
    if [ ! -f "$rCacheFile" ]; then
        echo "RFILE NOT EXIST" 
        return 1
    else
        echo "RFILE IN CACHED"
        return 0
    fi
}
        
genDfile() {
    local url="$1" xdownFile="$2" domain="$3"
    xPath="${downFile%/*}"
    tempdFile="${downFile##*^}"
    dFile="${xPath}/${tempdFile/.xplcdn/}"
    dFileName="${tempdFile/.xplcdn/}"
    rlocalFile="$rCacheFile"
    if [ -f "$rlocalFile" ]; then
        $xdelta3 -d -f -g "$rlocalFile" "/data/vhost/${downFile}" "/data/vhost/$dFile"
    	if [ $? -ne 0 ]; then
    	    echo "DFILE GENERATE FAILED"
    	    rm -f "/data/vhost/$dFile"
            return 1
    	else
    	    touch -r "/data/vhost/${downFile}" "/data/vhost/$dFile"
    	    echo "DFILE GENERATE OK"
    	    return 0
    	fi
    else
        echo "RFILE NOT FOUND"
        return 1
    fi
}
        
# Load local downfile to nginx cache
loadCache() {
    local url="$1" loadurl=${url/vhost\//}
    echo "$url" | tee -a ${wget_log}
    echo -e "--------------------\nSTART LOADCACHE:$loadurl" | tee -a ${wget_log}
    ngctool "rmf=$loadurl" $cccdir &>/dev/null
    codeNum=$(curl -I -H "VHOST: vhost" "$loadurl" -x 127.0.0.1:80 2>/dev/null | awk '/^HTTP\/1.1/{print $2}')
    test "$codeNum" == 200 && { echo -e "LOADCACHED OK\n100%";return 0; }
    test "$codeNum" == 404 && { echo -e "LOADCACHED FAILED\n0%";return 1; }
}
 
# Check whether the local cache is consistent with the source station       
checkMd5() {
    local url="$1" sETag=$2 loadurl=${url/vhost\//}
    echo "$url"  | tee -a ${wget_log}
    echo -e "--------------------\nSTART CHECKMD5:$loadurl" | tee -a ${wget_log} 
    if [ ! -z "$md5" ]; then
        while :
        do
            text=$(ngctool "md5=$loadurl" $cccdir 2>/dev/null)
            test -z "$text" && { sleep 5;continue; } || break 
        done
        localMd5=${text:0-32}
        
        echo -e "ORGmd5: == $md5 ==\nNODEmd5: == $localMd5 ==" | tee -a ${wget_log}
        test "$md5" == "$localMd5" && return 0 || return 1
    else
        nodeETag=$(curl -I -H "VHOST: vhost" "$loadurl" -x 127.0.0.1:80 2>/dev/null | awk -F '"' '/ETag/{print $2}')
        orgETag=$(curl -I "$loadurl" -x "$snode:80" 2>/dev/null | awk -F '"' '/ETag/{print $2}')
        echo -e "ORGETAG: == $sETag ==\nNODETAG: == $nodeETag ==\nTESTETAG: == $orgETag ==" | tee -a ${wget_log}
        test -z "$nodeETag" && { echo -e "FILE:$loadurl\nETAG FAILED";return 1; }
        test "$sETag" = "$nodeETag" -o "$orgETag" = "$nodeETag" && return 0 || return 1
    fi
}

Wget() {
    local url="$1"
    echo "VHOST DOWN FAILED, DIRECT DOWNLOAD NGINXCACHE" 
    echo "Delete old cache from: $url" 
    ngctool "rmf=$url" $cccdir 2>/dev/null
    /usr/bin/wget3 -O /dev/null  --header='Accept-Encoding:gzip, deflate, sdch' --max-redirect=0 \
    --progress=% ${url/vhost\//} -e http-proxy=127.0.0.1:80 2>&1 | tee -a ${wget_log}
}

# Get script pid
sPID=$$

# Defined variables
user=$1
id=$2
ip=$3
url=$4
size=$5
pnode=$6
sETag=$7
snode=$8
mode=$9
level=${10}
md5=${11}
download_dir=/data/vhost
log_path=/tmp/distribute/$user/$id
log_file=${log_path}/dist.log
wget_log=${log_path}/wget.log
test -d ${log_path} || mkdir -p ${log_path}
lock=$log_path/lock
gnode=121.32.230.227
filePath=${url##*://}
Path=${filePath%/*}
test -d ${download_dir}/${Path/vhost\//} || mkdir -p ${download_dir}/${Path/vhost\//}
File=${filePath##*/}
tempFile=${Path}/.tmp.${File}
tempDownFile=${tempFile/vhost\//}
vhostUrl="http://${tempFile}"
localFile=${url##*://}
downFile=${localFile/vhost\//}
tempSizeFile=/tmp/distribute/size.txt
:>$tempSizeFile
domain=${downFile%%/*}
fileBase=${downFile#*/}
suffix=${url##*.}
xdelta3="/usr/local/bin/xdelta3"
cccdir="/data/cache1/data /data/cache2/data /data/cache3/data /data/cache4/data /data1/cache1/data /data2/cache1/data /data3/cache1/data /data4/cache1/data /data5/cache1/data"
echo "$*" >> /tmp/distribute/access.log
test $# -eq 0 && { echo "No parameters";exit; }

# 差异文件分发
# 判断url后缀是否以.xplcdn结尾,是的话在本地查找源文件（母文件）是否存在
# 如果源文件不存则下载新文件，以普通分发的形式
# 如果源文件存在则普通方式下载差异文件

# 在远程连接过来时为了此脚本能在后台运行，并且返回脚本运行时的输出到远程机上，
# 在连接是会连续运行两次此脚本，第一次带全参数，会加锁运行脚本，第二次带两个参数来运行脚本，
# 如果是两个参数那么就直接tail日志文件返回到远程机上
# tail结束后退出脚本
if [ $# -eq 2 ]; then
    pid=$!
    while :
    do
        test -f ${wget_log} || { sleep 0.2 && continue; }
        tail -F -n3 --pid $pid ${wget_log}
        exit
    done 
fi

# 当客户是以边上传边分发的方式进行文件的上传与分发
# 那么在脚本运行完毕，所有节点都已返回结果之后，后台程序再次调用分发脚本，传递delete标记参数
# 分发脚本会再传递4个参数调用此脚本进行节点续传临时文件的清理
# 在清理完后退出脚本
if [ $# -eq 4 ]; then
    if [ "$suffix" == "xplcdn" ]; then
        xPath="${downFile%/*}"
        tempdFile="${downFile##*^}"
        dFile="$xPath/${tempdFile/.xplcdn/}"
        dFileName="${tempdFile/.xplcdn/}"
        rm -f "/data/vhost/${downFile}"   # xdelta文件
        rm -f "/data/vhost/${dFile}" # 目标生成文件
        xxx=$(ngctool "rmf=$url" $cccdir 2>/dev/null)
        echo "xxx: $xxx" | tee -a ${wget_log}
        echo -e "TEMPORARY FILE:\n\
        /data/vhost/${downFile}\n\
        /data/vhost/${dFile}\nDELETED OK\n100%" | tee -a ${wget_log}
    else
        rm -f "${download_dir}/${downFile}"
        rm -f "${download_dir}/${tempDownFile}"
        if [ ! -f "${download_dir}/${downFile}" -a ! -f "${download_dir}/${tempDownFile}" ]; then
            echo -e "TEMPORARY FILE:\n${downFile}\n${tempDownFile}\nDELETED OK\n100%" | tee -a ${wget_log}
        fi
    fi
    exit
fi

if [ "$suffix" == "xplcdn" ]; then
    checkRfile "${url/vhost\//}" "$fileBase" "$domain"
    if [ $? -eq 0 ]; then
        url="$url"
    else
        url="http://${localFile%/*}/$dFileName"
    fi
else
    url=$url
    dFile="$downFile"
    echo $dFile
fi


# Lock before start 
{
    flock -xn 33 || tailFile "$lock" "${wget_log}"
        echo "$sPID" > $lock
        loadurl=${url/vhost\//}
        if [ -z "$md5" ]; then 
            oldETag=$(ngctool -h "ls=$loadurl" $cccdir 2>/dev/null | grep ETag | cut -d '"' -f 2)
            test "$oldETag" == "$sETag" && { echo -e "=== CACHE EXISTS; NOTHING TO DO ===\n100%" | tee -a ${wget_log} && exit; }
        else
            text=$(ngctool "md5=$loadurl" $cccdir 2>/dev/null)
            localMd5=${text:0-32}
            echo -e "ORGmd5: == $md5 ==\nNODEmd5: == $localMd5 ==" | tee -a ${wget_log}
            test "$md5" == "$localMd5" && { echo -e "=== CACHE EXISTS; NOTHING TO DO ===\n100%" | tee -a ${wget_log} && exit; }
        fi
       
        suffix=${url##*.}
        test "$suffix" == "xplcdn" -a "$level" == "2" && url="http://vhost/${url##*//}"
        test "$pnode" = "114.119.10.168" && pnode="183.232.150.5"
        test "$pnode" = "114.119.10.169" && pnode="183.232.150.4"
        test "$pnode" = "27.155.94.210" && pnode="183.251.62.179"
        test "$pnode" = "122.224.152.154" && pnode="112.17.39.136"
	    
        if [ "$mode" = 2 ]; then  # mode=2 边传边发
	        i=0
            n=0
            b=0
            ln -sf "${download_dir}/${tempDownFile}" "${download_dir}/${downFile}"
	        while :
	        do
            wgetSlice "$user" "$vhostUrl" "$pnode" "$wget_log" "$download_dir" "$tempDownFile" "$size"
		    sta=$?
		    if [ "$sta" = "56" -o "$sta" = "166" -o "$sta" = "0" -o "$sta" = "102" ]; then
                read lastSize < "$tempSizeFile"
    		    downSize=$(du -b "${download_dir}/${tempDownFile}" | awk '{print $1}')
                test -z $lastSize && lastSize=$downSize
                if [ "$lastSize" -eq "$downSize" ]; then
                    let b++
                else
                    b=0
                    echo $downsize > $tempSizeFile
                fi
			    if [ "$downSize" = "$size" ]; then
                    echo -e "ORGSIZE:  $size\nDOWNSIZE: $downSize\nSLICE WGET DOWN\n100%"
                    break
                else
                    if [ $b -eq 360 ]; then
                        # 这里做一个客户暂停或中断上传操作的判断
                        # 下载文件半小时内大小无变化，则判定为客户中断了上传，便退出脚本
                        echo "==> SOURCE FILE ERROR"
                        rm -rf "${download_dir}/${tempDownFile}" "${download_dir}/${downFile}"
                        exit
                    fi
			        sleep 5 && continue
                fi
	    	elif [ "$sta" = "154" -o "$sta" = "4" -o "$sta" -gt "200" ]; then
                if [ $sta -eq 154 ]; then
                    let i++
                    test $level -eq 1 && vhostUrl="http://${localFile}"
                    test $i -eq 10 && { pnode=$snode && vhostUrl="http://${downFile}"; }
                    test $i -eq 20 && { pnode=$gnode && vhostUrl="http://vhost/${tempDownFile}"; }
                    if [ $i -eq 360 ]; then
                        echo "==> SOURCE FILE DOES NOT EXIST"
                        rm -rf "${download_dir}/${tempDownFile}" "${download_dir}/${downFile}"
                        exit
                    fi
                    sleep 5 && continue
                fi
			    let i++
			    test $i -eq 1 && { pnode=$gnode && vhostUrl="http://vhost/${tempDownFile}"; }
			    test $i -eq 2 && { pnode=$snode && vhostUrl="http://${downFile}"; }
			    test $i -ge 3 && break
			    continue
		    fi
	        done 2>&1 | tee ${wget_log}
        
	    elif [ "$mode" = 1 ]; then # mode=1 普通分发(上传完再分发)
            z=0
            f=0
            while :
            do  
            let z++
            suffix=${url##*.}
            echo -e "--------------------\nSTART WGETONE: $url"
            wgetOne "$url" "$pnode" "$wget_log" "$download_dir"
            sta=$?
            echo "wget3code:$sta"
            if [ $sta -eq 102 -o $sta -eq 154 ]; then
                let f++
                test "$sta" -eq "154" -a "$level" -eq "2" && { pnode=$snode;url=${url/vhost\//}; }
                test $f -eq 50 && break
                continue
            elif [ $sta -gt 200 ]; then
                test $z -eq 1 && continue
                test $z -eq 2 && pnode="$snode" && continue
                test $z -eq 3 && pnode="$gnode" && continue
            elif [ $sta -eq 4 ]; then
                pnode="$gnode"
                continue
            fi
            if [ "$suffix" == "xplcdn" ]; then       
                # 如果下载下来的文件为差异文件，刚调用genDfile生成目标文件
                # 生成成功，核验md5值是否与源一致，一致就跳出循环，进行其它项的检验
                # 生成失败，重新赋值url（新文件的）调用wgetOne 进行普通分发
                echo -e "--------------------\nSTART GENDFINE: $url"
                genDfile "${url/vhost\//}" "$fileBase" "$domain"
                if [ $? -eq 0 ]; then
                    dFileMd5=$(md5sum "/data/vhost/$dFile" | cut -d ' ' -f1)
                    if [ "$md5" == "$dFileMd5" ]; then
                        echo -e "MD5check OK\nORGMD5:$md5\nDFILEMD5:$dFileMd5\n100%" 
                        url="http://${dFile}"
                        break
                    else
                        echo -e "MD5check FAILED\nORGMD5:$md5\nDFILEMD5:$dFileMd5\nGO TO DOWN DFILE"
                        url="http://${dFile}"
                        wgetOne "$url" "$pnode" "$wget_log" "$download_dir"
                    fi
                else
                    url="http://${dFile}"
                    wgetOne "$url" "$pnode" "$wget_log" "$download_dir"
                fi
            fi
            break
            done 2>&1 | tee ${wget_log}
        fi
        url="http://${dFile}"
        loadCache "$url"
        test $? -eq 1 && Wget "$url" 2>&1 | tee -a ${wget_log}
        checkMd5 "$url" "$sETag"
        if [ $? -eq 0 ]; then
            echo -e "$ip $url : \n== CACHED OK ==\n100%" | tee -a ${wget_log}
            if [ "$mode" -eq "1" -a -z "$md5" ]; then
                rm -f "${download_dir}/${downFile}"
            else
                exit
            fi
            test ! -f "${download_dir}/${downFile}" && \
            echo -e "VHOSTFILE:DELETED\n${download_dir}/${dFile}\n100%" | tee -a ${wget_log}
        else
            echo -e "$ip $url : \n== Check ETag Failed ==\n0%" | tee -a ${wget_log}
            rm -f "${download_dir}/${downFile}"
            Wget "http://$dFile" 2>&1 | tee -a ${wget_log}
        fi
} 33>> $lock
