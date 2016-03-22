#!/bin/bash 

set -x
#############################################################
#
#  init_script.sh: Initialization Script to setup ceph on amazon AWS
#
# Modified by  		Date(dd/mm/yy)			Remarks
#------------------------------------------------------------
# Sandip L    		03/06/16                Initial Creation
# 
#############################################################

#This script needs to be executed on the local laptop
#This file assumes the existence of the AWS credentials key (aws1.pm) in current directory
#node-admin is the admin node
#node-admin is also the meta-data server
#node-admin is also the monitor node
#node0, node1, node2 are the cluster nodes
#All nodes host the OSD

awsKey="aws1.pem"
awsUser="ubuntu"
nodeAdmin="ec2-52-207-228-176.compute-1.amazonaws.com"

scp -i $awsKey $awsKey $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey setup_ceph.sh $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey setup_s3fs.sh $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey filegen.sh $awsUser@$nodeAdmin:/home/$awsUser

ssh -i $awsKey $awsUser@$nodeAdmin exec "chmod 775 setup_ceph.sh"
ssh -i $awsKey $awsUser@$nodeAdmin exec "./setup_ceph.sh"

