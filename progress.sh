#!/bin/sh

#b=''
#for ((i=0;$i<=100;i+=2))
#do
#        printf "progress:[%-50s]%d%%\r" $b $i
#        sleep 0.1
#        b=#$b
#done
#echo

i=0
bar=''
index=0
arr=( "|" "/" "-" "\\" )
while [ $i -le 100 ]
do
    let index=index%4
    printf "[%-50s][%d%%][\e[43;46;1m%c\e[0m]\r\r" "$bar" "$i" "${arr[$index]}"
    let i++
    let index++
    usleep 30000
    bar+='#'
done
printf "\n"


