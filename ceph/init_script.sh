#This script needs to be executed on the local laptop
#This file assumes the existence of the AWS credentials key (aws1.pm) in current directory
#node-admin is the admin node
#node-admin is also the meta-data server
#node-admin is also the monitor node
#node0, node1, node2 are the cluster nodes
#All nodes host the OSD

awsKey="aws1.pem"
awsUser="ubuntu"
nodeAdmin="ec2-54-175-96-226.compute-1.amazonaws.com"

scp -i $awsKey $awsKey $awsUser@$nodeAdmin:/home/$awsUser
scp -i $awsKey setup_ceph.sh $awsUser@$nodeAdmin:/home/$awsUser
ssh -i $awsKey $awsUser@$nodeAdmin exec "chmod 775 setup_ceph.sh"
ssh -i $awsKey $awsUser@$nodeAdmin exec "./setup_ceph.sh"

