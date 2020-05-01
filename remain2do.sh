#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2017-04-29 12:27:00
# Location: Dongguan
# Desc:     delete drms refresh job in node is down time 
#


url_list=$1
sitelist=/etc/nginx/webconf.d/sitelist.txt
localkey_dir=/data/localeUrlKey

delete_cacheFile() {
    while read url
    do
        ngctool rmf=$url 2>/dev/null
    done < "$url_list"
} 

delete_cacheDir() {
    grep -E "\.\*" "$url_list" | \
    while read url 
    do
        tempurl=${url##*//}
        domain=${tempurl%%/*}
        findurl=$(sed -r "s/$domain//" <<<$tempurl)
        domain_id=$(grep "$domain" $sitelist | awk '{print $1}')
        grep -E "$findurl" "$localkey_dir/$domain_id" | \
            while read xxx rmurl
            do
                ngctool rmf=http://${domain}${rmurl} 2>/dev/null
            done
    done
}

test $# -ne 1 && { echo "Use: $0 url_list";exit; }
delete_cacheFile
echo "delete cache file done.."

grep -qE "\.\*" "$url_list" || { echo "no dir refresh list, nothing to do..";exit; }
delete_cacheDir
echo "delete cache dir done.."
