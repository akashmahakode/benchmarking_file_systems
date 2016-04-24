#!/bin/bash 

generateSequentialDataset(){
	ip=`hostname`
	i=1
	rm $ip-file 
	while [ "$i" -le "$1" ]; do
		echo $ip-file$i >> $ip-file
		i=$(($i + 1))
	done
}

generateRandomDataset(){
	ip=`hostname`
	i=1
	rm $ip-file 
	cd some_dir
	while [ "$i" -le "$1" ]; do
		file=`shuf -n1 -e *`
		echo $file >> ../$ip-file
		i=$(($i + 1))
	done
	cd ..
}

sync(){
	ip=`hostname`
	#rm sync/$ip*
	touch sync/$ip-file-$1
	fileCount=`ls -l sync/*-$1 | grep -v ^l | wc -l`
	synccount=`expr $fileCount % 64`
	while [ $synccount != 0 ]
	do
		sleep 1
		#echo "waiting for sync $synccount"
		fileCount=`ls -l sync/*-$1 | grep -v ^l | wc -l`
		synccount=`expr $fileCount % 64`
	done
}


runEval(){
	fn=`hostname`
	sync WRITE$1$2
	echo "Running Evaluation for Write $1 x $2 ... " 
	(time ./filegen.sh $1 $2) &> ~/$fn-results.txt
    cat ~/$fn-results.txt
	sync READSEQ$1-$2
	echo "Running Evaluation for Sequential Read $1 x $2 ... " 
	generateSequentialDataset $1
	echo Sequential Data generated
	(time ./file_read.sh) &> ~/$fn-results.txt
    cat ~/$fn-results.txt
	sync READRAN$1-$2
	#echo "Running Evaluation for Random Read $1 x $2 ... " 
	#generateRandomDataset $1
	#echo Random Data generated
	#(time ./file_read.sh) &> ~/$fn-results.txt
    #cat ~/$fn-results.txt 
	echo "Delete $1 x $2 ... " 
	sync DEL$1-$2
	cd some_dir
	rm $fn*
	cd ..
}

fn=`hostname`

TIMEFORMAT='%3R'

#runEval 1 10240000000
#runEval 10 1024000000
#runEval 100 102400000
#runEval 1000 10240000
runEval 1000 1024000
runEval 1000 102400
runEval 1000 10240
runEval 10000 1024
runEval 10000 0

			
#echo "Running 0kb evaluation type 1" 
#sync 0KBOPT1
#mkdir $fn-some_dir; cd $fn-some_dir; time for i in {1..1000}; do touch $i.txt; done
#cd ..
#sync DELOPT1
#rm -rf $fn-some_dir


#echo "Running 0kb evaluation type 2" 
for i in {1..1000}; do echo $i.txt >> ~/tempFile; done 
tr '\n' ' ' < ~/tempFile > ~/tempFile1
var=`cat ~/tempFile1`
mkdir $fn-some_dir;  
sync 0KBOPT2  
cd $fn-some_dir    
(time time touch $var) &> ~/$fn-results.txt
cat ~/$fn-results.txt
cd ..
sync DELOPT2
rm -rf $fn-some_dir

rm sync/*





