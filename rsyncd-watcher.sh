#!/bin/bash

# uploadedx 1:user 2:xurl
deltaDist() {
    local user=$1 scheme=$2 domain=$3 delta="$4" md5=$5 size=$6
    deltaName=${delta##*/}
    urlPath=$(awk -F "$domain" '{print $2}' <<<"$file" | cut -d '/' -f1)
    test ! -z $urlPath && \
    xURL="$scheme://$domain/$urlPath/$deltaName" || \
    xURL="$scheme://$domain/$deltaName"

    echo "*** Delta distribute file $xURL"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $xURL deltadist start" >> "$log_file"
    http_code=$(curl -o /dev/null -I -s -w %{http_code} "$xURL" -x 127.0.0.1:80)
    if [ "$http_code" == "200" ]; then
        msg=$(curl -d "url=${xURL}&filesize=${size}&md5=${md5}" "http://my.down.speedtopcdn.com/index.php/ajax/purgeUrl" -x 127.0.0.1:80 2>/dev/null)
        # {"succ":true,"id":0,"flag":0,"msg":"","size":"0","count":1,"count_need":0,"count_404":0,"count_ignore":1}
        jobid=$(cut -d ':' -f 3 <<<"$msg" | cut -d ',' -f1)
        if [ "$jobid" -eq 0 ]; then
            echo "file no change,nothing to do"
        else
            while :
            do
                checkStat "$jobid"
                test $? -eq 0 && break || { sleep 5;continue; }
            done
        fi   
        sleep 1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $url deltadist OK" >> "$log_file"
    fi 
}

checkStat() {
    local jobid=$1
    text=$(curl -d "id=$jobid" "http://my.down.speedtopcdn.com/index.php/ajax/schedule" -x 127.0.0.1:80 2>/dev/null)
    sopStat=$(cut -d ',' -f3 <<<"$text" | cut -d ':' -f2 | cut -d '.' -f1 | tr -d '}')
    distStat=$(cut -d ',' -f4 <<<"$text" | cut -d ':' -f2 | tr -d '}')
    # {"s":5,"i":25059,"p":100.00,"st":5}
    test -z $sopStat && sopStat=0
    test -z $distStat && distStat=0
    if [ "$sopStat" == "100" -o "$distStat" == "5" ]; then
        return 0
    else
        return 1
    fi
}
    
regDist() {
    local user=$1 domain=$2 url=$3
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $url regdist start" >> "$log_file"
    http_code=$(curl -o /dev/null -I -s -w %{http_code} "$url" -x 127.0.0.1:80)
    if [ "$http_code" == "200" ]; then
        #curl -d "url=$url" "http://my.down.speedtopcdn.com/index.php/ajax/purgeUrl" -x 127.0.0.1:80 &>/dev/null
        sleep 1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $url regdist OK" >> "$log_file"
    fi
}

# uploaded 1:user 2:domain 3:file 4:sent_size 5:size 6:refer_file 7:md5 8:base
Dist() {
    local user="$1" domain="$2" file="$3" sent_size="$4" size="$5" refer_file="$6" md5="$7" base="$8"
    local filename="${file##*/}"
    local filePath="${file%/*}"
    local delta="${refer_file}^${filename}.${xext}"
    touch -r "$file" "$filePath/.${filename}.$md5.$size"
    chown nginx.nginx "$filePath/.${filename}.$md5.$size"
    chmod 755 "$filePath/.${filename}.$md5.$size"
    echo "* uploaded $*"
    rm -f "$delta"
  
    if [ "$file" == "$refer_file" ]; then
        if [ -f "$file~" ]; then
            echo "*** Updated: $file"
            xdelta3 -e -f -s "$file~" "$file" "$delta" || >&2 echo "Warning: failed to run xdelta3"
            chown nginx.nginx "$delta"
            chmod 755 "$delta"
            rm -fr "$file~"
        else
            echo "*** New: $file"
        fi
    else
        echo "*** DeltaNew: $file ref: $refer_file"
        if [ -f "$refer_file" ]; then
            xdelta3 -e -f -s "$refer_file" "$file" "$delta" || >&2 echo "Warning: failed to run xdelta3"
            chown nginx.nginx "$delta"
            chmod 755 "$delta"
        fi
    fi
    if [ -f "$delta" ]; then
        xsize=$(($(stat -c%s "$delta")*100/80))
        if [ "$xsize" -gt "$size" ]; then
            # The xdelta3 size bigger then 80% of original size we treat it is bad
            echo "*** Delta size is too big: $(ls -l $delta)"
            rm -fr "$delta"
            # go normal: new-file size
            echo "*** Regular distribute file $domnai $sent_size"
            regDist $user "$scheme://$domain/$base"
        else
            # go delta ref-file delta-file new-file size
            echo "*** Delta distribute file $6 $delta $file $5"
            deltaDist "$user" "$scheme" "$domain" "$delta" "$md5" "$size"
        fi
    fi
}

# deleted 1:user 2:URL
deleted() {
    local user=$1 url=$2 
    echo "** Purge file [$url] from all nodes..."
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $url del start" >> "$log_file"
    curl --retry 3 --retry-delay 10 --connect-timeout 300 -m 300 \
    -d "rmurl=$url" "http://my.down.speedtopcdn.com/index.php/ajax/purgeUrl" \
    -x 127.0.0.1:80 &>/dev/null
    sleep 1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $url del OK" >> "$log_file"
}

genFromx() {
    local xfile="$1"
    rfile="${xfile%^*}"
    test -f "$rfile" || echo "referfile $rfile not exist"  
    xpath="${xfile%/*}"
    tempdfile="${xfile##*^}"
    dfileName="${tempdfile/.xplcdn/}"
    dfile="$xpath/${dfileName}"
    xdelta3 -d -s "$rfile" "$xfile" "$dfile"
    dFileMd5=$(md5sum "$dfile" 2>/dev/null | cut -d ' ' -f1)
    if [ -f "$dfile" ]; then
        touch -r "$xfile" "$dfile"
        chown nginx.nginx "$dfile"
        chmod 755 "$dfile"
        dsize=$(stat -c%s "$dfile")
        dFileMd5=$(md5sum "$dfile" 2>/dev/null | cut -d ' ' -f1)
        touch -r "$xfile" "${xpath}/.${dfileName}.${dFileMd5}.${dsize}"
        chown nginx.nginx "${xpath}/.${dfileName}.${dFileMd5}.${dsize}"
        chmod 755 "${xpath}/.${dfileName}.${dFileMd5}.${dsize}"
        return 0
    else
        echo "xdelta3 returned error: $dfile"
        return 2
    fi
}
    
rsync_log="/var/log/rsync/rsync.log"
rsync_root="/data/cache1/ftp"
log_dir=/tmp/rsync-dist
test -d $log_dir || mkdir $log_dir
log_file=$log_dir/rsync_dist.log
mark="<baodecdn>"
xext="xplcdn"

#2016/07/04 12:00:46 [8122] <baodecdn> [114.119.10.163] (john) recv bb.jc.com download/apk/something.pak 4137 4096 download/apk/e.pak
#2016/07/04 11:58:08 [8088] <baodecdn> [114.119.10.163] (john) del. bb.jc.com t.php 0 0 %x
tail -F -n0 "$rsync_log" | while read line
do
    items=(${line})
    if [ "${items[3]}" == "$mark" ]; then
        echo "Matched: $line"
        user="${items[5]}"
        oper="${items[6]}"
        scheme="${items[7]}"
        domain="${items[8]}"
        base="${items[9]}"
        file="$rsync_root/$user/$domain/$base"

        if [ "$oper" == "recv" ]; then
            chmod 0755 ${file}
            suffix="${base##*.}"
            if [ "$suffix" == "$xext" ]; then
                genFromx "$file"
                if [ $? -eq 0 ]; then
                    deltaDist "$user" "$scheme" "$domain" "$base" "$dFileMd5" "$dsize"
                fi
            else
                sent_size="${items[10]}"
                size="${items[11]}"
                rfile="/${items[12]}"
                md5="${items[13]}"
                Dist "$user" "$domain" "$file" "$sent_size" "$size" "$rfile" "$md5" "$base"
            fi
        else
            if [ "$oper" == "del." ]; then
                deleted "$user" "$scheme/$domain/$base"
            fi
        fi
    else
        echo "Ignored: $line"
    fi
done
