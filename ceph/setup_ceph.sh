#!/bin/bash 

set -x
#############################################################
#
#  setup_ceph.sh: Script to setup ceph on amazon AWS
#
# Modified by  		Date(dd/mm/yy)			Remarks
#------------------------------------------------------------
# Sandip L    		03/06/16                Initial Creation
# 
#############################################################

#This script needs to be executed on the admin node
#This file assumes the existence of the AWS credentials key (aws1.pm) in current directory
#node-admin is the admin node
#node0 is also the meta-data server
#node0 is also the monitor node
#node0, node1, node2 are the cluster nodes
#All nodes host the OSD


awsKey="aws1.pem"
awsUser="ubuntu"
REPLICAS=1

#Monitor Node 1, Admin Node 0
#Private IP of monitor node
#monIP="172.31.5.51"
monIP=`sed '2q;d' private.txt`

readarray node < dnsNames.txt
readarray ipNode < ipNames.txt

NUM_NODES=${#node[@]}

ssh-keygen -t rsa -b 2048
i=1
while [  $i -lt $NUM_NODES ]; do
	var="node$COUNTER"
	cat .ssh/id_rsa.pub | ssh -o StrictHostKeyChecking=no -i $awsKey ${node[$i]} "cat - >> ~/.ssh/authorized_keys2"
    let i=i+1 
done

#Install ceph on admin-node
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
echo deb http://download.ceph.com/debian-hammer/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
sudo apt-get update
sudo apt-get install ceph-deploy

#Install ceph on the other cluster nodes
i=0
while [ $i -lt $NUM_NODES ]; do
	#var="ipNode$COUNTER"
	#ceph-deploy purge ${!var}
	ceph-deploy purgedata ${ipNode[$i]}
	ceph-deploy install ${ipNode[$i]}
    let i=i+1 
done

i=1
#Deploy node1 as the monitor
ceph-deploy new ${ipNode[$i]}
ceph-deploy mon create ${ipNode[$i]}
ceph-deploy gatherkeys ${ipNode[$i]}

i=1
while [ $i -lt $NUM_NODES ]; do
	ssh -o StrictHostKeyChecking=no ${ipNode[$i]} exec "sudo mkdir /tmp/osd;exit"
	ssh -o StrictHostKeyChecking=no ${ipNode[$i]} exec "sudo mkdir /mnt/mycephfs;exit"
	let i=i+1 
done
sudo mkdir /tmp/osd
sudo mkdir /mnt/mycephfs

#Prepare and activate OSD
i=0
while [ $i -lt $NUM_NODES ]; do
	name=`echo ${ipNode[$i]} | xargs`
	ceph-deploy osd prepare $name:/tmp/osd 
	let i=i+1 
done

i=1
while [ $i -lt $NUM_NODES ]; do
	ssh -o StrictHostKeyChecking=no ${ipNode[$i]} exec "sudo chown -R ceph:ceph /tmp/osd;exit"
	let i=i+1 
done
sudo chown -R ceph:ceph /tmp/osd

i=0
while [ $i -lt $NUM_NODES ]; do
	name=`echo ${ipNode[$i]} | xargs`
	ceph-deploy osd activate $name:/tmp/osd 
	let i=i+1 
done

i=1
#Deploy node1 as the monitor
ceph-deploy mds create ${ipNode[$i]}

#Setup Cluster access from all nodes
#ceph-deploy admin $ipNode3 $ipNode0 $ipNode1 $ipNode2
i=0
while [ $i -lt $NUM_NODES ]; do
	ceph-deploy admin ${ipNode[$i]}
	let i=i+1 
done


i=1
#Provide permissions to key
while [ $i -lt $NUM_NODES ]; do
	ssh -o StrictHostKeyChecking=no ${ipNode[$i]} exec "sudo chmod +r /etc/ceph/ceph.client.admin.keyring;exit"
	let i=i+1 
done
sudo chmod +r /etc/ceph/ceph.client.admin.keyring

ceph health

#ceph-deploy purge $ipNode1 
#ceph-deploy purgedata $ipNode1 
#Total PGs = (OSDs * 100)/Replicas

let PG=NUM_NODES*100/REPLICAS

ceph osd pool create cephfs_data $PG
ceph osd pool create cephfs_metadata $PG

ceph osd pool set cephfs_data size 1
ceph osd pool set cephfs_metadata size 1

ceph fs new cephfs cephfs_metadata cephfs_data
ceph fs ls
ceph mds stat

# mounting volumes
secretkey=`cat /etc/ceph/ceph.client.admin.keyring	| grep key | awk '{print $NF}'`

i=1
while [ $i -lt $NUM_NODES ]; do
	var="ipNode$COUNTER"
	ssh -o StrictHostKeyChecking=no ${ipNode[$i]} exec "sudo mount -t ceph $monIP:6789:/ /mnt/mycephfs -o name=admin,secret=$secretkey;exit"
	let i=i+1 
done	
sudo mount -t ceph $monIP:6789:/ /mnt/mycephfs -o name=admin,secret=$secretkey

i=1
# deploy rgs on gateway node
ceph-deploy rgw create ${ipNode[$i]}
sudo radosgw-admin user create --uid="testuser" --display-name="First User"

#i=1
#while [ $i -lt $NUM_NODES ]; do
#	var="ipNode$COUNTER"
	#scp filegen.sh ${!var}:/home/$awsUser
	#scp random_file_read.sh ${!var}:/home/$awsUser
	#scp benchmarking.sh ${!var}:/home/$awsUser
	#scp setup_s3fs.sh ${!var}:/home/$awsUser
	#ssh -o StrictHostKeyChecking=no ${!var} exec "sudo mkdir /mnt/mycephfs/benchmarking$COUNTER;exit"
	#ssh -o StrictHostKeyChecking=no ${!var} exec "sudo chown ubuntu:ubuntu /mnt/mycephfs/benchmarking$COUNTER;exit"
	#ssh -o StrictHostKeyChecking=no ${!var} exec "cp ~/filegen.sh /mnt/mycephfs/benchmarking$COUNTER;exit"
	#ssh -o StrictHostKeyChecking=no ${!var} exec "cp ~/random_file_read.sh /mnt/mycephfs/benchmarking$COUNTER;exit"
	#ssh -o StrictHostKeyChecking=no ${!var} exec "cp ~/benchmarking.sh /mnt/mycephfs/benchmarking$COUNTER;exit"
	#ssh -o StrictHostKeyChecking=no ${!var} exec "chmod 775 /mnt/mycephfs/benchmarking$COUNTER/*;exit"
	
	#	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo chmod 775 setup_s3fs.sh;exit"
	#	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo ./setup_s3fs.sh;exit"
	#	ssh -o StrictHostKeyChecking=no ${!var} exec "cp ~/filegen.sh /mnt/mys3fs/benchmarking$COUNTER;exit"
	#	ssh -o StrictHostKeyChecking=no ${!var} exec "cp ~/filegen.sh /mnt/mys3fs/benchmarking$COUNTER;exit"
	#	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo chown ubuntu:ubuntu /mnt/mys3fs/benchmarking$COUNTER;exit"
#	let i=i+1 
#done	

sudo mkdir /mnt/mycephfs/benchmarking$i	
sudo chown ubuntu:ubuntu /mnt/mycephfs/benchmarking$i
cp ~/filegen.sh /mnt/mycephfs/benchmarking$i
cp ~/file_read.sh /mnt/mycephfs/benchmarking$i
cp ~/benchmarking.sh /mnt/mycephfs/benchmarking$i
cp ~/open.sh /mnt/mycephfs/benchmarking$i
chmod 775 /mnt/mycephfs/benchmarking$i/* 
mkdir /mnt/mycephfs/benchmarking$i/some_dir 
mkdir /mnt/mycephfs/benchmarking$i/sync

#sudo chmod 775 setup_s3fs.sh
#sudo ./setup_s3fs.sh
#sudo mkdir /mnt/mys3fs/benchmarking$COUNTER
#sudo chown ubuntu:ubuntu /mnt/mys3fs/benchmarking$COUNTER
#cp ~/filegen.sh /mnt/mys3fs/benchmarking$COUNTER

	
