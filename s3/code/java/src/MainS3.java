import com.amazonaws.AmazonClientException;
import com.amazonaws.AmazonServiceException;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.regions.Region;
import com.amazonaws.regions.Regions;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3Client;
import com.amazonaws.services.s3.model.CreateBucketRequest;
import com.amazonaws.services.s3.model.ObjectListing;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.amazonaws.services.s3.model.S3ObjectSummary;
import com.amazonaws.services.s3.transfer.MultipleFileDownload;
import com.amazonaws.services.s3.transfer.MultipleFileUpload;
import com.amazonaws.services.s3.transfer.TransferManager;
import com.google.common.base.Stopwatch;
import org.apache.commons.io.FileUtils;

import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.net.InetAddress;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;


class S3Benchmarker {

    private String AWS_ACCESS_KEY_ID;
    private String AWS_SECRET_ACCESS_KEY;
    private String BUCKET_NAME;
    private BasicAWSCredentials awsCredentials;
    private AmazonS3 s3Client;
    private String DIR_NAME_S3;
    private String dirToUse;

    private List<File> evaluationDirectories;
    /**
     * key --> fileSize:fileCount:SINGLE
     *         fileSize:fileCount:BULK
     * value --> timeTaken
     */
    private Map<String, String> resultMap;

    private StringBuffer logBuffer = new StringBuffer();

    public S3Benchmarker(){

        logBuffer.append(getTimeStamp()+ " : INFO : Inside S3BenchMarker constructor \n");
        if(!setup()){
            try {
                throw new Exception("Can not run benchmarking for S3...");
            } catch (Exception e) {
                e.printStackTrace();
                logBuffer.append(getTimeStamp()+ " : ERROR : Exception occured while setup \n"+ e.getLocalizedMessage());
            }
        }
    }


    boolean startEvaluation(long size, int count) throws IOException {
        try {
            uploadFiles(size, count);
            cleanup(true, false);
            downloadFiles(size, count);
            cleanup(true, false);
        } catch (AmazonServiceException ase) {
            printException(ase);
        } catch (AmazonClientException ace) {
            ace.printStackTrace();
            System.out.println("Caught an AmazonClientException, which " +
                    "means the client encountered " +
                    "an internal error while trying to " +
                    "communicate with S3, " +
                    "such as not being able to access the network.");
            System.out.println("Error Message: " + ace.getMessage());
            logBuffer.append(getTimeStamp() + " : ERROR : Exception occured while setup \n" + ace.getMessage());
        }
        return false;
    }

    private void printException(AmazonServiceException ase) {
        ase.printStackTrace();
        System.out.println("Caught an AmazonServiceException, which " +
                "means your request made it " +
                "to Amazon S3, but was rejected with an error response" +
                " for some reason.");
        System.out.println("Error Message:    " + ase.getMessage());
        System.out.println("HTTP Status Code: " + ase.getStatusCode());
        System.out.println("AWS Error Code:   " + ase.getErrorCode());
        System.out.println("Error Type:       " + ase.getErrorType());
        System.out.println("Request ID:       " + ase.getRequestId());
        logBuffer.append(getTimeStamp() + " : ERROR : Exception occured while setup \n" + ase.getLocalizedMessage());
        logBuffer.append("Error Message:    \n" + ase.getMessage());
        logBuffer.append("HTTP Status Code: \n" + ase.getStatusCode());
        logBuffer.append("AWS Error Code:   \n" + ase.getErrorCode());
        logBuffer.append("Error Type:       \n" + ase.getErrorType());
        logBuffer.append("Request ID:       \n" + ase.getRequestId());
    }

    private void downloadFiles(long size, int count) {
        File dirName = createDirectory("file_size_"+size);
        logBuffer.append(getTimeStamp() + " : INFO : Downloading " + count + "  files of size : " + FileUtils.byteCountToDisplaySize(size) + " " +
                " to S3 \"IN BULK\"\n");
        System.out.println(getTimeStamp() + " : INFO : Downloading  " + count + "  files of size : " + FileUtils.byteCountToDisplaySize(size) + " " +
                " to S3 \"IN BULK\"\n");

        TransferManager tm = new TransferManager(s3Client);
        Stopwatch timer = Stopwatch.createStarted();
        MultipleFileDownload download = tm.downloadDirectory(BUCKET_NAME, dirToUse, dirName);
        try {
            download.waitForCompletion();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        Stopwatch stop = timer.stop();
        resultMap.put("fileSize="+FileUtils.byteCountToDisplaySize(size)+" : fileCount="+count+" : BULK",
                stop.elapsed(TimeUnit.MILLISECONDS)+" ms OR "+stop.elapsed(TimeUnit.SECONDS)+" sec");
        System.out.println(getTimeStamp() + " : INFO : INFO : Finished downloading " + count +  "  files of size : " + FileUtils.byteCountToDisplaySize(size) +" from S3 ");
        System.out.println(getTimeStamp() + " : INFO : Downloaded "+count+" in the S3 bucket - "+BUCKET_NAME);
        System.out.println(getTimeStamp() + " : INFO : Total time taken in Microseconds : "+stop.elapsed(TimeUnit.MICROSECONDS));
        System.out.println(getTimeStamp() + " : INFO : Total time taken in Milliseconds : " + stop.elapsed(TimeUnit.MILLISECONDS));
        System.out.println(getTimeStamp() + " : INFO : Total time taken in Seconds : " + stop.elapsed(TimeUnit.SECONDS));
        System.out.println(getTimeStamp() + " : INFO : Total time taken in Minutes : " + stop.elapsed(TimeUnit.MINUTES));

        logBuffer.append(getTimeStamp() + " :  INFO : Finished Downloading " + count + "  files of size : " + FileUtils.byteCountToDisplaySize(size) +" from S3 \n");
        logBuffer.append(getTimeStamp() + " :  INFO : Total time taken in Microseconds : " + stop.elapsed(TimeUnit.MICROSECONDS) + "\n");
        logBuffer.append(getTimeStamp() + " :  INFO : Total time taken in Milliseconds : " + stop.elapsed(TimeUnit.MILLISECONDS)+"\n");
        logBuffer.append(getTimeStamp() + " :  INFO : Total time taken in Seconds : " + stop.elapsed(TimeUnit.SECONDS)+"\n");
        logBuffer.append(getTimeStamp() + " :  INFO : Total time taken in Minutes : " + stop.elapsed(TimeUnit.MINUTES)+"\n");
    }

    /**
     *Upload the files to S3 bucket
     * @param fileSize, size of file in Bytes
     * @param fileCount
     */
    private void uploadFiles(long fileSize, int fileCount) throws IOException {
        File dirName = createDirectory("file_size_"+fileSize);

        logBuffer.append(getTimeStamp() + " : INFO : Creating " + fileCount + "  files of size : " + FileUtils.byteCountToDisplaySize(fileSize) + " " +
                " on " + InetAddress.getLocalHost() + "\n");
        System.out.println(getTimeStamp() + " : INFO : Creating  " + fileCount + "  files of size : " + FileUtils.byteCountToDisplaySize(fileSize) + " " +
                " on " + InetAddress.getLocalHost() + "\n");

        for (int i = 1; i <= fileCount ; i ++){
            RandomAccessFile file = new RandomAccessFile(dirName.getPath() + File.separator + i+".txt", "rw");
            file.setLength(fileSize);
            file.close();
        }

        logBuffer.append(getTimeStamp() + " : INFO : Created " + fileCount + "  files of size : " + FileUtils.byteCountToDisplaySize(fileSize) + " " +
                " on " + InetAddress.getLocalHost() + "\n");
        System.out.println(getTimeStamp() + " : INFO : Created  " + fileCount + "  files of size : " + FileUtils.byteCountToDisplaySize(fileSize) + " " +
                " on " + InetAddress.getLocalHost() + "\n");

        logBuffer.append(getTimeStamp() + " : INFO : Uploading " + fileCount + "  files of size : " + FileUtils.byteCountToDisplaySize(fileSize) + " " +
                " to S3 \"IN BULK\"\n");
        System.out.println(getTimeStamp() + " : INFO : Uploading  " + fileCount + "  files of size : " + FileUtils.byteCountToDisplaySize(fileSize) + " " +
                " to S3 \"IN BULK\"\n");

        TransferManager tm = new TransferManager(s3Client);
        Stopwatch timer = Stopwatch.createStarted();
        dirToUse = DIR_NAME_S3+ File.separator+ "oneshot";
        MultipleFileUpload upload = tm.uploadDirectory(BUCKET_NAME, dirToUse, dirName, true);

        try {
            upload.waitForCompletion();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        Stopwatch stop = timer.stop();
        resultMap.put("fileSize="+FileUtils.byteCountToDisplaySize(fileSize)+" : fileCount="+fileCount+" : BULK",
                stop.elapsed(TimeUnit.MILLISECONDS)+" ms OR "+stop.elapsed(TimeUnit.SECONDS)+" sec");
        System.out.println(getTimeStamp() + " : INFO : INFO : Finished uploading " + fileCount +  "  files of size : " + FileUtils.byteCountToDisplaySize(fileSize) +" to S3 ");
        System.out.println(getTimeStamp() + " : INFO : Uploaded "+fileCount+" in the S3 bucket - "+BUCKET_NAME);
        System.out.println(getTimeStamp() + " : INFO : Total time taken in Microseconds : "+stop.elapsed(TimeUnit.MICROSECONDS));
        System.out.println(getTimeStamp() + " : INFO : Total time taken in Milliseconds : " + stop.elapsed(TimeUnit.MILLISECONDS));
        System.out.println(getTimeStamp() + " : INFO : Total time taken in Seconds : " + stop.elapsed(TimeUnit.SECONDS));
        System.out.println(getTimeStamp() + " : INFO : Total time taken in Minutes : " + stop.elapsed(TimeUnit.MINUTES));

        logBuffer.append(getTimeStamp() + " :  INFO : Finished uploading " + fileCount + "  files of size : " + FileUtils.byteCountToDisplaySize(fileSize) +" to S3 \n");
        logBuffer.append(getTimeStamp() + " :  INFO : Total time taken in Microseconds : " + stop.elapsed(TimeUnit.MICROSECONDS) + "\n");
        logBuffer.append(getTimeStamp() + " :  INFO : Total time taken in Milliseconds : " + stop.elapsed(TimeUnit.MILLISECONDS)+"\n");
        logBuffer.append(getTimeStamp() + " :  INFO : Total time taken in Seconds : " + stop.elapsed(TimeUnit.SECONDS)+"\n");
        logBuffer.append(getTimeStamp() + " :  INFO : Total time taken in Minutes : " + stop.elapsed(TimeUnit.MINUTES)+"\n");
    }

    /**
     * Read environment variables such as aws access key, secret key, bucket name, number of files etc
     * @return true if setup is successful
     */
    private boolean setup() {
        logBuffer.append(getTimeStamp()+ " : INFO : Setup started \n");
        resultMap = new HashMap<String, String>();
        boolean isSuccess = false;

        AWS_ACCESS_KEY_ID = System.getenv("AWS_ACCESS_KEY_ID");
        AWS_SECRET_ACCESS_KEY = System.getenv("AWS_SECRET_ACCESS_KEY");
        BUCKET_NAME = System.getenv("BUCKET_NAME");

        if (AWS_ACCESS_KEY_ID == null || AWS_SECRET_ACCESS_KEY == null || BUCKET_NAME == null) {
            logBuffer.append(getTimeStamp()+ " : ERROR : AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / BUCKET_NAME may be null \n");
            isSuccess = false;
        }else{
            awsCredentials = new BasicAWSCredentials(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY);
            s3Client = new AmazonS3Client(awsCredentials);
            s3Client.setRegion(Region.getRegion(Regions.US_EAST_1));
            // checks whether bucket exists or not, if not then create a new bucket
            boolean bucketExist = s3Client.doesBucketExist(BUCKET_NAME);
            if(!bucketExist){
                System.out.println("Bucket with name " + BUCKET_NAME + " does not exist, " +
                        "Creating the bucket " + BUCKET_NAME + " now");
                logBuffer.append(getTimeStamp() + " : INFO : Bucket with name " + BUCKET_NAME + " does not exist, " +
                        "Creating the bucket " + BUCKET_NAME + " now. \n");
                s3Client.createBucket(new CreateBucketRequest(BUCKET_NAME));
                logBuffer.append(getTimeStamp()+ " : INFO : Bucket created :  " + BUCKET_NAME+" \n");
            }
            evaluationDirectories = new ArrayList<File>();
            isSuccess = true;
        }
        return isSuccess;
    }

    private File createDirectory(String folderName){
        //Create Directory to store the empty files
        Date date = Calendar.getInstance().getTime();
        SimpleDateFormat sdf = new SimpleDateFormat("yyyyMMdd_hhmmss");
        String dirName = sdf.format(date);

        String userHome = System.getProperty("user.home");
        System.out.println("Creating empty directories locally in user's home directory " + userHome);
        logBuffer.append(getTimeStamp()+ " : INFO : \"Creating empty directories locally in user's home directory "+userHome +"\n");

        File directory = new File(userHome+ File.separator+"cs597_s3_eval"+ File.separator + dirName);
        directory.mkdirs();
        //Store the directories which are created, this will help in cleaning up
        evaluationDirectories.add(directory);
        DIR_NAME_S3 = "cs597_s3_eval"+ File.separator + folderName + File.separator +
                dirName +"_"+ UUID.randomUUID();
        return directory;
    }

    /**
     * Delete all empty files and directories which were created locally and in s3 bucket
     */
    protected void cleanup(boolean deleteLocal, boolean deleteBucketData){
        logBuffer.append(getTimeStamp()+ " : INFO : Cleanup started. \n");
        if(deleteLocal){
            //Delete all directories created locally
            for(File dir : evaluationDirectories){
                logBuffer.append(getTimeStamp() + " : INFO : Deleting local directory " + dir.getPath() + "\n");
                try {
                    FileUtils.deleteDirectory(dir);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }

        if(deleteBucketData){
            // empty the bucket
            logBuffer.append(getTimeStamp() + " : INFO : Deleting the contents of bucket : " + BUCKET_NAME + "\n");
            ObjectListing objects = s3Client.listObjects(BUCKET_NAME, DIR_NAME_S3);
            for (S3ObjectSummary objectSummary : objects.getObjectSummaries()){
                s3Client.deleteObject(BUCKET_NAME, objectSummary.getKey());
            }

            objects = s3Client.listObjects(BUCKET_NAME, DIR_NAME_S3+ File.separator+ "oneshot");
            for (S3ObjectSummary objectSummary : objects.getObjectSummaries()){
                s3Client.deleteObject(BUCKET_NAME, objectSummary.getKey());
            }
        }
    }

    public String getTimeStamp(){
        Date date = Calendar.getInstance().getTime();
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd_hh:mm:ss:SSS");
        return sdf.format(date);
    }

    public StringBuffer getLogBuffer() {
        return logBuffer;
    }

    public AmazonS3 getS3Client() {
        return s3Client;
    }

    public String getBUCKET_NAME() {
        return BUCKET_NAME;
    }

    public Map<String, String> getResultMap() {
        return resultMap;
    }
}

public class MainS3{
    public static void main(String[] args) throws IOException {
        System.out.println("***********************************************************************");
        System.out.println("****                              WARNING                         *****");
        System.out.println("***********************************************************************");
        System.out.println("Make sure that you export following variables correctly, otherwise ...*");
        System.out.println("AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, BUCKET_NAME");
        System.out.println("***********************************************************************");

        S3Benchmarker s3Benchmarker = null;
        try{
            s3Benchmarker = new S3Benchmarker();
            s3Benchmarker.startEvaluation(Long.parseLong(args[0]), Integer.parseInt(args[1]));
        }finally {
            StringBuffer logBuffer = s3Benchmarker.getLogBuffer();
            logBuffer.append("Final Result for S3 Evaluation with time stamps \n");
            Map<String, String> resultMap = s3Benchmarker.getResultMap();

            System.out.println("***********************************************************************");
            for (String key : resultMap.keySet()) {
                System.out.println(key + " --> " + resultMap.get(key));
                logBuffer.append(key + " --> " + resultMap.get(key)+"\n");
            }
            System.out.println("***********************************************************************");
            //put the log files in s3 bucket to keep the track of benchmarking
            String logs = s3Benchmarker.getLogBuffer().toString();
            String logFile = "log-"+s3Benchmarker.getTimeStamp()+".log";
            String logFilePath = System.getProperty("user.home")+ File.separator+ logFile;
            File file = new File(logFilePath);
            AmazonS3 s3Client = s3Benchmarker.getS3Client();
            FileUtils.writeStringToFile(file, logs);
            s3Client.putObject(new PutObjectRequest(s3Benchmarker.getBUCKET_NAME(), "logs/" + logFile, file));
            System.exit(0);
        }
    }
}