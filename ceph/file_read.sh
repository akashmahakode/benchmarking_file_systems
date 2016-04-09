#!/bin/bash 
ip=`hostname`
readarray a < $ip-file
cd some_dir
i=0
while [ "$i" -lt "${#a[@]}" ]; do
	../open.sh ${a[$i]}
	i=$(($i + 1))
done
cd ..

