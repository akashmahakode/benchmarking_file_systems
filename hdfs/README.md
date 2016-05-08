Step 1. Create RSA public keypair on each of the machine
> cd ~
> ssh-keygen -t rsa

Do not enter any paraphrase, instead just press [enter].

Step 2. Open  /etc/ssh/ssh_config with sudo in vi (or any editor of your choice)
Add following at the end of /etc/ssh/ssh_config
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null

Step 3. Copy the key pair file someKeyPair.pem to master node's home directory:
> scp -i /path-of-someKeyPair/someKeyPair.pem /path-of-someKeyPair/someKeyPair.pem ubuntu@public-dns-master:/home/ubuntu

Step 4: Run setPasswordless.sh as -
> setPasswordless.sh /someKeyPair.pem

Enter the public DNS name of the master node e.g 
ec2-54-205-45-8.compute-1.amazonaws.com

Then it will ask for the slave public dns names separated by white space, Please make sure that you enter master dns name as well. Because Hadoop
needs master should be able to perform passwordless ssh to itself.


