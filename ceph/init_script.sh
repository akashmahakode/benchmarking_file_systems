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

# get ceph instances
#create dns files
aws ec2 describe-instances --filters "Name=group-name,Values=CephOpen" --query "Reservations[*].Instances[*].PublicDnsName" | grep ec | sed 's/ //g' | sed 's/"//g' > dnsNames.txt
#create ipFiles
aws ec2 describe-instances --filters "Name=group-name,Values=CephOpen" --query "Reservations[*].Instances[*].PrivateDnsName" | grep ip | sed 's/ //g' | sed 's/"//g' > ipNames.txt
aws ec2 describe-instances --filters "Name=group-name,Values=CephOpen" --query "Reservations[*].Instances[*].PrivateIpAddress" | grep \" | sed 's/ //g' | sed 's/"//g' > private.txt

nodeAdmin=$(head -n 1 dnsNames.txt)


scp -i $awsKey $awsKey $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey setup_ceph.sh $awsUser@$nodeAdmin:/home/$awsUser
#scp -i $awsKey setup_s3fs.sh $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey filegen.sh $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey file_read.sh $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey benchmarking.sh $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey open.sh $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey dnsNames.txt $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey ipNames.txt $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey private.txt $awsUser@$nodeAdmin:/home/$awsUser

ssh -i $awsKey $awsUser@$nodeAdmin exec "chmod 775 setup_ceph.sh"
ssh -i $awsKey $awsUser@$nodeAdmin exec "./setup_ceph.sh"

