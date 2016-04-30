    #!/bin/bash
   
    KEY_PAIR=$1
  
    # Make sure you have transferred your key-pair to master
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
      echo "Expects ~/.ssh/id_rsa.pub to be created. Run ssh-keygen -t rsa from home directory"
      exit
    fi
     
    if [ ! -f ~/KEY_PAIR ]; then
      echo "For enabling password-less ssh, transfer KEY_PAIR to master's home folder (e.g.: scp -i /local-path/KEY_PAIR /local-path/KEY_PAIR ubuntu@master_public_dns:~)"
      exit
    fi
     
    echo "Provide following ip-addresses"
    echo -n -e "${green}Public${endColor} dns address of master:"
    read MASTER_IP
    echo ""
     
    # Assumption here is that you want to create a small cluster ~ 10 nodes
    echo -n -e "${green}Public${endColor} dns addresses of slaves (separated by space):"
    read SLAVE_IPS
    echo "" 
     
    echo -n -e "Do you want to enable password-less ssh between ${green}master-slaves${endColor} (y/n):"
    read ENABLE_PASSWORDLESS_SSH
    echo ""
    if [ "$ENABLE_PASSWORDLESS_SSH" == "y" ]; then
      # Copy master's public key to itself
      #cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
     
      for SLAVE_IP in $SLAVE_IPS
      do
          echo "Checking passwordless ssh between master -> "$SLAVE_IP
        ssh -o PasswordAuthentication=no $SLAVE_IP /bin/true
        IS_PASSWORD_LESS="n"
        if [ $? -eq 0 ]; then
            echo "Passwordless ssh has been setup between master -> "$SLAVE_IP
            echo "Now checking passwordless ssh between "$SLAVE_IP" -> master"
     
          ssh $SLAVE_IP 'ssh -o PasswordAuthentication=no' $MASTER_IP '/bin/true'  
          if [ $? -eq 0 ]; then
              echo "Passwordless ssh has been setup between "$SLAVE_IP" -> master"
            IS_PASSWORD_LESS="y"
          fi
        fi
     
        if [ "$IS_PASSWORD_LESS" == "n" ]; then
          # ssh-copy-id gave me lot of issues, so will use below commands instead
          echo "Enabling passwordless ssh between master and "$SLAVE_IP
     
          # Copy master's public key to slave
          cat ~/.ssh/id_rsa.pub | ssh -i ~/KEY_PAIR "ubuntu@"$SLAVE_IP 'mkdir -p ~/.ssh ; cat >> ~/.ssh/authorized_keys' 
          # Copy slave's public key to master
          ssh -i ~/KEY_PAIR "ubuntu@"$SLAVE_IP 'cat ~/.ssh/id_rsa.pub' >> ~/.ssh/authorized_keys
          # Copy slave's public key to itself
          ssh -i ~/KEY_PAIR "ubuntu@"$SLAVE_IP 'cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys'
     
        fi    
      done
     
      echo ""
      echo "---------------------------------------------"
      echo "Testing password-less ssh on master -> slave"
      for SLAVE_IP in $SLAVE_IPS
      do
        ssh "ubuntu@"$SLAVE_IP  uname -a
      done
     
      echo ""
      echo "Testing password-less ssh on slave -> master"
      for SLAVE_IP in $SLAVE_IPS
      do
        ssh "ubuntu@"$SLAVE_IP 'ssh ' $MASTER_IP 'uname -a'
      done
      echo "---------------------------------------------"
      echo "Sorry, prefer to keep this check manual to avoid headache in Hadoop or any other distributed program."
      echo -n -e "Do you see error or something fishy in above block (y/n):"
      read IS_ERROR1
      echo ""
      if [ "$IS_ERROR1" == "y" ]; then
        echo "I am sorry to hear this script didn't work for you :("
        echo "Hint1: Its quite possible, slave doesnot contain ~/KEY_PAIR"
        echo "Hint2: sudo vim /etc/ssh/ssh_config and add StrictHostKeyChecking no and UserKnownHostsFile=/dev/null to it"
        exit
      fi
    fi
     
    echo -n -e "Do you want to enable password-less ssh between ${green}slave-slave${endColor} (y/n):"
    read ENABLE_PASSWORDLESS_SSH1
    echo ""
    if [ "$ENABLE_PASSWORDLESS_SSH1" == "y" ]; then
      if [ "$ENABLE_PASSWORDLESS_SSH" == "n" ]; then
        echo -n -e "In this part, the key assumption is that password-less ssh between ${green}master-slave${endColor} is enabled. Do you still want to continue (y/n):"
        read ANS1
        if [ "$ANS1" == "n" ]; then 
          exit
        fi
        echo ""
     
      fi
      for SLAVE_IP1 in $SLAVE_IPS
      do
        for SLAVE_IP2 in $SLAVE_IPS
        do
          if [ "$SLAVE_IP1" != "$SLAVE_IP2" ]; then
            # Checking assumes passwordless ssh has already been setup between master and slaves
              echo "[Warning:] Skipping checking passwordless ssh between "$SLAVE_IP1" -> "$SLAVE_IP2
            IS_PASSWORDLESS_SSH_BETWEEN_SLAVE_SET="n"
     
            # This will be true because ssh $SLAVE_IP1 is true
            #ssh $SLAVE_IP1 ssh -o PasswordAuthentication=no $SLAVE_IP2 /bin/true
            #if [ $? -eq 0 ]; then
     
     
            if [ "$IS_PASSWORDLESS_SSH_BETWEEN_SLAVE_SET" == "n" ]; then
              echo "Enabling passwordless ssh between "$SLAVE_IP1" and "$SLAVE_IP2
              # Note you are on master now, which we assume to have 
              ssh -i ~/KEY_PAIR $SLAVE_IP1 'cat ~/.ssh/id_rsa.pub' | ssh -i ~/KEY_PAIR $SLAVE_IP2 'cat >> ~/.ssh/authorized_keys' 
            else
              echo "Passwordless ssh has been setup between "$SLAVE_IP1" -> "$SLAVE_IP2
            fi
          fi
        done
     
      done
     
      echo "---------------------------------------------"
      echo "Testing password-less ssh on slave  slave"
      for SLAVE_IP1 in $SLAVE_IPS
      do
        for SLAVE_IP2 in $SLAVE_IPS
        do
          # Also, test password-less ssh on the current slave machine
          ssh $SLAVE_IP1 'ssh ' $SLAVE_IP2 'uname -a'
        done
      done
      echo "---------------------------------------------"
      echo "Sorry, prefer to keep this check manual to avoid headache in Hadoop or any other distributed program."
      echo -n -e "Do you see error or something fishy in above block (y/n):"
      read IS_ERROR1
      echo ""
      if [ "$IS_ERROR1" == "y" ]; then
        echo "I am sorry to hear this script didn't work for you :("
        echo "Hint1: Its quite possible, slave doesnot contain ~/KEY_PAIR"
        echo "Hint2: sudo vim /etc/ssh/ssh_config and add StrictHostKeyChecking no and UserKnownHostsFile=/dev/null to it"
        exit
      fi
    fi
