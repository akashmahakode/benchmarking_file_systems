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

NUM_NODES=4
awsKey="aws1.pem"
awsUser="ubuntu"
nodeAdmin="ec2-52-207-228-176.compute-1.amazonaws.com"
node0="ec2-52-90-96-126.compute-1.amazonaws.com"
node1="ec2-52-90-161-212.compute-1.amazonaws.com"
node2="ec2-52-90-160-231.compute-1.amazonaws.com"

ipNode3="ip-172-31-15-233.ec2.internal"
ipNode0="ip-172-31-9-79.ec2.internal"
ipNode1="ip-172-31-11-25.ec2.internal"
ipNode2="ip-172-31-12-208.ec2.internal"

#IP of monitor node
monIP="172.31.9.79"

NUM_NODES=4
TEMP=3

ssh-keygen -t rsa -b 2048
COUNTER=0
while [  $COUNTER -lt $TEMP ]; do
	var="node$COUNTER"
	cat .ssh/id_rsa.pub | ssh -o StrictHostKeyChecking=no -i $awsKey ${!var} "cat - >> ~/.ssh/authorized_keys2"
    let COUNTER=COUNTER+1 
done

#Install ceph on admin-node
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
echo deb http://download.ceph.com/debian-hammer/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
sudo apt-get update
sudo apt-get install ceph-deploy

#Install ceph on the other cluster nodes
COUNTER=0
while [ $COUNTER -lt $NUM_NODES ]; do
	var="ipNode$COUNTER"
	#ceph-deploy purge ${!var}
	ceph-deploy purgedata ${!var}
	ceph-deploy install ${!var}
    let COUNTER=COUNTER+1 
done

#Deploy node0 as the monitor
ceph-deploy new $ipNode0
ceph-deploy mon create $ipNode0
ceph-deploy gatherkeys $ipNode0

COUNTER=0
while [ $COUNTER -lt $TEMP ]; do
	var="ipNode$COUNTER"
	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo mkdir /tmp/osd;exit"
	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo mkdir /mnt/mycephfs;exit"
	let COUNTER=COUNTER+1 
done
sudo mkdir /tmp/osd
sudo mkdir /mnt/mycephfs

#Prepare and activate OSD
COUNTER=0
while [ $COUNTER -lt $NUM_NODES ]; do
	var="ipNode$COUNTER"
	ceph-deploy osd prepare ${!var}:/tmp/osd 
	let COUNTER=COUNTER+1 
done

COUNTER=0

while [ $COUNTER -lt $TEMP ]; do
	var="ipNode$COUNTER"
	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo chown -R ceph:ceph /tmp/osd;exit"
	let COUNTER=COUNTER+1 
done
sudo chown -R ceph:ceph /tmp/osd

COUNTER=0
while [ $COUNTER -lt $NUM_NODES ]; do
	var="ipNode$COUNTER"
	ceph-deploy osd activate ${!var}:/tmp/osd 
	let COUNTER=COUNTER+1 
done

#Deploy node0 as the monitor
ceph-deploy mds create $ipNode0

#Setup Cluster access from all nodes
ceph-deploy admin $ipNode3 $ipNode0 $ipNode1 $ipNode2

COUNTER=0
#Provide permissions to key
while [ $COUNTER -lt $TEMP ]; do
	var="ipNode$COUNTER"
	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo chmod +r /etc/ceph/ceph.client.admin.keyring;exit"
	let COUNTER=COUNTER+1 
done
sudo chmod +r /etc/ceph/ceph.client.admin.keyring

ceph health

#ceph-deploy purge $ipNode1 
#ceph-deploy purgedata $ipNode1 
#Total PGs = (OSDs * 100)/Replicas

ceph osd pool create cephfs_data 400
ceph osd pool create cephfs_metadata 400

ceph osd pool set cephfs_data size 1
ceph osd pool set cephfs_metadata size 1

ceph fs new cephfs cephfs_metadata cephfs_data
ceph fs ls
ceph mds stat

# mounting volumes
secretkey=`cat /etc/ceph/ceph.client.admin.keyring	| grep key | awk '{print $NF}'`

COUNTER=0	
while [ $COUNTER -lt $TEMP ]; do
	var="ipNode$COUNTER"
	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo mount -t ceph $monIP:6789:/ /mnt/mycephfs -o name=admin,secret=$secretkey;exit"
	let COUNTER=COUNTER+1 
done	
sudo mount -t ceph $monIP:6789:/ /mnt/mycephfs -o name=admin,secret=$secretkey

# deploy rgs on gateway node
ceph-deploy rgw create $ipNode1
sudo radosgw-admin user create --uid="testuser" --display-name="First User"

COUNTER=0
while [ $COUNTER -lt $TEMP ]; do
	var="ipNode$COUNTER"
	scp filegen.sh ${!var}:/home/$awsUser
	scp setup_s3fs.sh ${!var}:/home/$awsUser
	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo mkdir /mnt/mycephfs/benchmarking$COUNTER;exit"
	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo chown ubuntu:ubuntu /mnt/mycephfs/benchmarking$COUNTER;exit"
	ssh -o StrictHostKeyChecking=no ${!var} exec "cp ~/filegen.sh /mnt/mycephfs/benchmarking$COUNTER;exit"
	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo chmod 775 setup_s3fs.sh;exit"
	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo ./setup_s3fs.sh;exit"
	ssh -o StrictHostKeyChecking=no ${!var} exec "cp ~/filegen.sh /mnt/mys3fs/benchmarking$COUNTER;exit"
	ssh -o StrictHostKeyChecking=no ${!var} exec "cp ~/filegen.sh /mnt/mys3fs/benchmarking$COUNTER;exit"
	ssh -o StrictHostKeyChecking=no ${!var} exec "sudo chown ubuntu:ubuntu /mnt/mys3fs/benchmarking$COUNTER;exit"
	let COUNTER=COUNTER+1 
done	

sudo mkdir /mnt/mycephfs/benchmarking$COUNTER	
sudo chown ubuntu:ubuntu /mnt/mycephfs/benchmarking$COUNTER
cp ~/filegen.sh /mnt/mycephfs/benchmarking$COUNTER

sudo chmod 775 setup_s3fs.sh
sudo ./setup_s3fs.sh
sudo mkdir /mnt/mys3fs/benchmarking$COUNTER
sudo chown ubuntu:ubuntu /mnt/mys3fs/benchmarking$COUNTER
cp ~/filegen.sh /mnt/mys3fs/benchmarking$COUNTER

	
