#create directory
pssh -h /tmp/ips.txt -l ubuntu  -t 100000000 -x  "-oStrictHostKeyChecking=no  -i /Users/amahakode/Documents/akash/study/cs597/Spark/spark-rdd-akash.pem" -o /tmp/del_out 'mkdir /home/ubuntu/s3_eval'
#copy jar
pscp -h /tmp/ips.txt -l ubuntu   -t 100000000 -x "-oStrictHostKeyChecking=no  -i /Users/amahakode/Documents/akash/study/cs597/Spark/spark-rdd-akash.pem" /Users/amahakode/Documents/akash/study/cs597/github/benchmarking_file_systems/s3fs/code/java/out/artifacts/s3_java_jar/s3_java.jar  /home/ubuntu/s3_eval
#run the jar
pssh -h /tmp/ips.txt -l ubuntu  -t 100000000 -x "-oStrictHostKeyChecking=no  -i /Users/amahakode/Documents/akash/study/cs597/Spark/spark-rdd-akash.pem" -o /tmp/del_out 'export AWS_ACCESS_KEY_ID=AKIAIO7SLI6DHXNFBMNA; export AWS_SECRET_ACCESS_KEY=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; export BUCKET_NAME=akashdel;java -jar /home/ubuntu/s3_eval/s3_java.jar 0 10000; java -jar /home/ubuntu/s3_eval/s3_java.jar 1024 10000'
