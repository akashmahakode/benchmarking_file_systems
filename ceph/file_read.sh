#!/bin/bash 
ip=`hostname`
readarray a < $ip-file
cd some_dir
i=0
while [ "$i" -lt "${#a[@]}" ]; do
	cat ${a[$i]} > /dev/null
	i=$(($i + 1))
done
cd ..

