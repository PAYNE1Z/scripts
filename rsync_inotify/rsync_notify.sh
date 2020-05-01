#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-12-12 14:36:23
# Location: DongGuang
# Desc:     rsync + inotify auto rync change file to remote host
#

host='172.16.0.232'
src='/var/www/html/zt_cms/frontend/web/cmshtml'    
dst='cmshtml'
user='cms'
inotify_args='modify,delete,create,attrib'
rsync_args='--delete --progress --password-file=/etc/rsyncd.passwd'

/usr/local/bin/inotifywait -mrq --timefmt '%d/%m/%y %H:%M' --format '%T %w%f%e' -e $inotify_args $src | \
while read files 
    do
        /usr/bin/rsync -vzrtopg $rsync_args $src/ $user@$host::$dst 
        echo "${files} was rsynced" >>/tmp/rsync.log 2>&1 
    done
