#!/bin/bash 

count="$1"
size="$2"
fn=`hostname`

#mkdir some_dir;
cd some_dir;

i=1
while [ "$i" -le "$count" ]; do
	if [ "$size" -gt 5000000000 ]
	then
		size=`expr  $size / 2`
    	perl -e 'print "a" x '$size'' >> $fn-file$i
	fi
perl -e 'print "a" x '$size'' >> $fn-file$i
	i=$(($i + 1))
done

cd ..
