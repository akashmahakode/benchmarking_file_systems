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
import com.amazonaws.services.s3.transfer.TransferManager;
import org.apache.commons.io.FileUtils;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.UUID;


class S3Benchmarker {

    private String AWS_ACCESS_KEY_ID;
    private String AWS_SECRET_ACCESS_KEY;
    private String BUCKET_NAME;
    // set number of files to 1000 by default
    private int NUM_FILES = 1000;


    private BasicAWSCredentials awsCreds;

    private AmazonS3 s3Client;

    private String DIR_NAME_S3;

    private List<File> evaluationDirectories;

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


    boolean createEmptyFiles() throws IOException {
        try {
            createOneFileAtATime();
            createMultipleFilesInOneShot();

            TransferManager tm = new TransferManager(s3Client);


            //  MultipleFileUpload upload = tm.uploadDirectory(BUCKET_NAME,
            //        "BuildNumber#1", "FilePathYouWant", true);


        } catch (AmazonServiceException ase) {
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

    private void createMultipleFilesInOneShot() {

    }

    private void createOneFileAtATime() throws IOException {
        File dirName = createDirectory();

        for (int i = 1; i <= NUM_FILES ; i ++){
            File file = new File(dirName.getPath() + File.separator + i+".txt");
            file.createNewFile();
        }
        logBuffer.append(getTimeStamp()+ " : INFO : Uploading a "+NUM_FILES+" empty files to S3 \n");
        System.out.println("INFO : Uploading a "+NUM_FILES+" empty files to S3 ");
        for (int i = 1; i <= NUM_FILES ; i ++){
            String key = DIR_NAME_S3+ File.separator + i+".txt";
            String fileName = dirName.getPath() + File.separator + i+".txt";
            s3Client.putObject(new PutObjectRequest(BUCKET_NAME, key, fileName));
        }
        System.out.println("INFO : Finished uploading "+NUM_FILES+" empty files to S3 ");
        logBuffer.append(getTimeStamp() + " :  INFO : Finished uploading "+NUM_FILES+" empty files to S3 \n");
    }

    /**
     * Read environment variables such as aws access key, secret key, bucket name, number of files etc
     * @return true if setup is successful
     */
    private boolean setup() {
        logBuffer.append(getTimeStamp()+ " : INFO : Setup started \n");
        boolean isSuccess = false;

        AWS_ACCESS_KEY_ID = System.getenv("AWS_ACCESS_KEY_ID");
        AWS_SECRET_ACCESS_KEY = System.getenv("AWS_SECRET_ACCESS_KEY");
        BUCKET_NAME = System.getenv("BUCKET_NAME");
        //NUM_FILES = Integer.parseInt(System.getenv("NUM_FILES"));
        NUM_FILES = 10;
        if (AWS_ACCESS_KEY_ID == null || AWS_SECRET_ACCESS_KEY == null || BUCKET_NAME == null) {
            logBuffer.append(getTimeStamp()+ " : ERROR : AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / BUCKET_NAME may be null \n");
            isSuccess = false;
        }else{
            awsCreds = new BasicAWSCredentials(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY);
            s3Client = new AmazonS3Client(awsCreds);
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

    private File createDirectory(){
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
        DIR_NAME_S3 = "cs597_s3_eval"+ File.separator + dirName +"_"+ UUID.randomUUID();
        return directory;
    }

    /**
     * Delete all empty files and directories which were created localy and in s3 bucket
     */
    protected void cleanup(){
        logBuffer.append(getTimeStamp()+ " : INFO : Cleanup started. \n");
        //Delete all directories created locally
        for(File dir : evaluationDirectories){
            logBuffer.append(getTimeStamp()+ " : INFO : Deleting local directory "+dir.getPath() +"\n");
            dir.delete();
        }

        // empty the bucket
        logBuffer.append(getTimeStamp() + " : INFO : Deleting the contents of bucket : " + BUCKET_NAME + "\n");
        ObjectListing objects = s3Client.listObjects(BUCKET_NAME, DIR_NAME_S3);
        for (S3ObjectSummary objectSummary : objects.getObjectSummaries()){
            s3Client.deleteObject(BUCKET_NAME, objectSummary.getKey());
        }

        //put the log files in s3 bucket to keep the track of benchmarking

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
}

public class MainS3{
    public static void main(String[] args) throws IOException {
        System.out.println("***********************************************************************");
        System.out.println("****                              WARNING                         *****");
        System.out.println("***********************************************************************");
        System.out.println("Make sure that you export following variables correctly, otherwise ...*");
        System.out.println("AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, BUCKET_NAME, NUM_FILES");
        System.out.println("***********************************************************************");


        S3Benchmarker s3Benchmarker = null;
        try{
            s3Benchmarker = new S3Benchmarker();
            s3Benchmarker.createEmptyFiles();
            // Do a cleanup
            s3Benchmarker.cleanup();
        }finally {
            String logs = s3Benchmarker.getLogBuffer().toString();
            String logFile = "log-"+s3Benchmarker.getTimeStamp()+".log";
            String logFilePath = System.getProperty("user.home")+ File.separator+ logFile;
            File file = new File(logFilePath);
            AmazonS3 s3Client = s3Benchmarker.getS3Client();
            FileUtils.writeStringToFile(file, logs);
            s3Client.putObject(new PutObjectRequest(s3Benchmarker.getBUCKET_NAME(), "logs/"+logFile, file));
        }

    }
}