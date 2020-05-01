#!/usr/bin/evn bash

checkNum=$1

grep -qE "123|234|345|456|567|678|789|987|876|765|654|543|432|321" <<<$checkNum && \
echo -e "\E[1;32m $checkNum: mathing.. \E[0m" || \
echo -e "\E[1;31m $checkNum: not mathing.. \E[0m" 
