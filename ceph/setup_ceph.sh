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
nodeAdmin="ec2-54-175-96-226.compute-1.amazonaws.com"
node0="ec2-52-201-244-92.compute-1.amazonaws.com"
node1="ec2-54-174-100-169.compute-1.amazonaws.com"
node2="ec2-52-201-252-139.compute-1.amazonaws.com"

ipNode3="ip-172-31-14-128.ec2.internal"
ipNode0="ip-172-31-7-158.ec2.internal"
ipNode1="ip-172-31-0-84.ec2.internal"
ipNode2="ip-172-31-4-225.ec2.internal"

NUM_NODES=4

ssh-keygen -t rsa -b 2048
COUNTER=0
while [  $COUNTER -lt $NUM_NODES-1 ]; do
	var="node$COUNTER"
	cat .ssh/id_rsa.pub | ssh -i $awsKey $awsUser@${!var} "cat - >> ~/.ssh/authorized_keys2"
    let COUNTER=COUNTER+1 
done

#Install ceph on admin-node
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
echo deb http://download.ceph.com/debian-hammer/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
sudo apt-get update
sudo apt-get install ceph-deploy

#Install ceph on the other cluster nodes
COUNTER=0
while [  $COUNTER -lt $NUM_NODES ]; do
	var="ipNode$COUNTER"
	ceph-deploy install ${!var}
    let COUNTER=COUNTER+1 
done

#Deploy node0 as the monitor
ceph-deploy new $ipNode0
ceph-deploy mon create $ipNode0
ceph-deploy gatherkeys $ipNode0

COUNTER=0
while [  $COUNTER -lt $NUM_NODES-1 ]; do
	var="ipNode$COUNTER"
	ssh ${!var} exec "sudo mkdir /tmp/osd;exit"
	let COUNTER=COUNTER+1 
done
sudo mkdir /tmp/osd

#Prepare and activate OSD
COUNTER=0
while [  $COUNTER -lt $NUM_NODES ]; do
	var="ipNode$COUNTER"
	ceph-deploy osd prepare ${!var}:/tmp/osd 
	exit
    let COUNTER=COUNTER+1 
done

COUNTER=0
while [  $COUNTER -lt $NUM_NODES-1 ]; do
	var="ipNode$COUNTER"
	ssh ${!var} exec "sudo chown -R ceph:ceph /tmp/osd;exit"
	let COUNTER=COUNTER+1 
done
sudo mkdir /tmp/osd

COUNTER=0
while [  $COUNTER -lt $NUM_NODES ]; do
	var="ipNode$COUNTER"
	ceph-deploy osd activate ${!var}:/tmp/osd 
	exit
    let COUNTER=COUNTER+1 
done

#Deploy node0 as the monitor
ceph-deploy mds create ipNode0






