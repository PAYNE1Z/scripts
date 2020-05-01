#!/bin/bash


urllist=/root/100net.txt
while read url
    do
        curl -I $url -x 127.0.0.1:80
        test $? -eq 0 && echo OK
    done < $urllist


