package com.kineticdata.bridgehub.adapter.amazonec2;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.BridgeUtils;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.commons.v1.config.ConfigurableProperty;
import com.kineticdata.commons.v1.config.ConfigurablePropertyMap;
import java.io.IOException;
import java.util.Date;
import java.util.Map;
import java.util.TimeZone;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.apache.commons.codec.binary.Hex;
import org.apache.commons.codec.digest.*;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.json.XML;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.LoggerFactory;


public class AmazonEC2Adapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/
    
    /** Defines the adapter display name */
    public static final String NAME = "Amazon EC2 Bridge (Legacy)";
    
    /** Defines the logger */
    protected static final org.slf4j.Logger logger = LoggerFactory.getLogger(AmazonEC2Adapter.class);
    
    /** Adapter version constant. */
    public static String VERSION;
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(AmazonEC2Adapter.class.getResourceAsStream("/"+AmazonEC2Adapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            logger.warn("Unable to load "+AmazonEC2Adapter.class.getName()+" version properties.", e);
            VERSION = "Unknown";
        }
    }
    
    /** Defines the collection of property names for the adapter */
    public static class Properties {
        public static final String ACCESS_KEY = "Access Key";
        public static final String SECRET_KEY = "Secret Key";
        public static final String ENDPOINT = "Endpoint";
        public static final String HOST = "Host";
        public static final String REGION = "Region";
        public static final String ACTION = "Action";
        public static final String API_VERSION = "API Version";
    }
    
    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
        new ConfigurableProperty(Properties.ACCESS_KEY).setIsRequired(true),
        new ConfigurableProperty(Properties.SECRET_KEY).setIsRequired(true).setIsSensitive(true),
        new ConfigurableProperty(Properties.ENDPOINT).setIsRequired(true),
        new ConfigurableProperty(Properties.HOST).setIsRequired(true),
        new ConfigurableProperty(Properties.REGION).setIsRequired(true),
        new ConfigurableProperty(Properties.ACTION).setIsRequired(true),
        new ConfigurableProperty(Properties.API_VERSION).setIsRequired(true)
    );
    
    private String accessKey;
    private String secretKey;
    private String endpoint;
    private String host;
    private String region;
    private String action;
    private String apiVersion;
    
    /*---------------------------------------------------------------------------------------------
     * SETUP METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public void initialize() throws BridgeError {
        this.accessKey = properties.getValue(Properties.ACCESS_KEY);
        this.secretKey = properties.getValue(Properties.SECRET_KEY);
        this.endpoint = properties.getValue(Properties.ENDPOINT);
        this.host = properties.getValue(Properties.HOST);
        this.region = properties.getValue(Properties.REGION);
        this.action = properties.getValue(Properties.ACTION);
        this.apiVersion = properties.getValue(Properties.API_VERSION);
//        testAuth();
    }
    
    @Override
    public String getName() {
        return NAME;
    }
    
    @Override
    public String getVersion() {
        return VERSION;
    }
    
    @Override
    public void setProperties(Map<String,String> parameters) {
        properties.setValues(parameters);
    }
    
    @Override
    public ConfigurablePropertyMap getProperties() {
        return properties;
    }
    
    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        String structure = request.getStructure();
        AmazonEC2QualificationParser parser = new AmazonEC2QualificationParser();
        String query = parser.parse(request.getQuery(),request.getParameters());

        TimeZone tz = TimeZone.getTimeZone("UTC");
        DateFormat df = new SimpleDateFormat("yyyyMMdd'T'HHmmss");
        df.setTimeZone(tz);
        final String amazonDate = df.format(new Date()) + "Z";
        
        DateFormat ds = new SimpleDateFormat("yyyyMMdd");
        ds.setTimeZone(tz);
        String dateStamp = ds.format(new Date());
        String canonicalQueryString = String.format("Action=%s&Version=%s", this.action, this.apiVersion);
        String canonicalHeaders = String.format("host:%s\nx-amz-date:%s\n", this.host, amazonDate);
        String signedHeaders = "host;x-amz-date";
        String text = "";
        String payloadHash = DigestUtils.sha256Hex(text);
        String canonicalRequest = "GET\n/\n" + canonicalQueryString + "\n" + canonicalHeaders + "\n" + signedHeaders + "\n" + payloadHash;
        String credentialScope = String.format("%s/%s/ec2/aws4_request", dateStamp, this.region);
        
        String output = "";
        
        try {
            byte[] signingKey = getSignatureKey(this.secretKey, dateStamp, this.region, "ec2");
            String canonicalRequestHash = DigestUtils.sha256Hex(canonicalRequest);
            String stringToSign = String.format("AWS4-HMAC-SHA256\n%s\n%s\n%s", amazonDate, credentialScope, canonicalRequestHash);
            Mac sha256_HMAC = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretkey = new SecretKeySpec(signingKey, "HmacSHA256");
            sha256_HMAC.init(secretkey);
            byte[] hash = sha256_HMAC.doFinal(stringToSign.getBytes());
            String signature = Hex.encodeHexString(hash);
            String authorizationHeader = String.format("AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=host;x-amz-date, Signature=%s", this.accessKey, credentialScope, signature);
            String url = String.format("%s?%s", this.endpoint, canonicalQueryString);
            
            HttpClient client = new DefaultHttpClient();
            HttpGet get = new HttpGet(url);
            get.setHeader("Content-Type", "application/x-www-form-urlencoded");
            get.setHeader("x-amz-date", amazonDate);
            get.setHeader("Authorization", authorizationHeader);

            HttpResponse response;

            try {
                response = client.execute(get);
                HttpEntity entity = response.getEntity();
                output = EntityUtils.toString(entity);
            } 
            catch (IOException e) {
                throw new BridgeError("Unable to make a connection to properly execute the query to Amazon EC2");
            }
        
        } catch (Exception ex) {
            throw new BridgeError("Unable to make a connection to properly execute the query to Amazon EC2");
        }
        
        JSONObject jsonOutput = XML.toJSONObject(output);
        JSONObject reservationSet = jsonOutput.getJSONObject("DescribeInstancesResponse").getJSONObject("reservationSet");
        JSONArray outputArray = reservationSet.optJSONArray("item");
        // Check for the case where item isn't a JSON Array and has either 0 or 1 objects
        if (outputArray == null) {
            outputArray = new JSONArray();
            JSONObject item = reservationSet.optJSONObject("item");
            if (item != null) outputArray.put(item);
        }
                
        Pattern pattern = Pattern.compile("([\"\"])(?:(?=(\\\\?))\\2.)*?\\1");
        Matcher matcher = pattern.matcher(query);
        
        // Query is case sensitive
        while (matcher.find()) {
            String key = matcher.group();
            // used to replace the outside quotes from the key value
            key = key.replaceAll("^\"|\"$", "");
            if (!key.equals("*")) {
                // While there is still a value contained within double quotes
                matcher.find();
                String value = matcher.group();
                // used to replace the outside quotes from the value
                value = value.replaceAll("^\"|\"$", "");
                
                // Array to get the index of jsonObject that doesn't match
                // the query. This will help when we remove from jsonOutput
                // as elements shift.
                List<Integer> indices = new ArrayList<Integer>();

                for (int i = 0; i < outputArray.length(); i++) {
                    if (outputArray.getJSONObject(i).getJSONObject("instancesSet").optJSONObject("item") instanceof JSONObject) {
                        String rec = outputArray.getJSONObject(i).getJSONObject("instancesSet").getJSONObject("item").getString("instanceId");
                        if (!value.equals(rec)) {
                            indices.add(i);
                        }
                    } else {
                        indices.add(i);
                    }
                }

                Collections.sort(indices, Collections.reverseOrder());
                for (int i : indices) {
                    outputArray.remove(i);
                }
            }
        }

        Long count;
        count = Long.valueOf(outputArray.length());

        return new Count(count);
    }

    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {
        List<String> fields = request.getFields();
        String structure = request.getStructure();
        AmazonEC2QualificationParser parser = new AmazonEC2QualificationParser();
        String query = parser.parse(request.getQuery(),request.getParameters());
        
        TimeZone tz = TimeZone.getTimeZone("UTC");
        DateFormat df = new SimpleDateFormat("yyyyMMdd'T'HHmmss");
        df.setTimeZone(tz);
        final String amazonDate = df.format(new Date()) + "Z";
        
        DateFormat ds = new SimpleDateFormat("yyyyMMdd");
        ds.setTimeZone(tz);
        String dateStamp = ds.format(new Date());
        String canonicalQueryString = String.format("Action=%s&Version=%s", this.action, this.apiVersion);
        String canonicalHeaders = String.format("host:%s\nx-amz-date:%s\n", this.host, amazonDate);
        String signedHeaders = "host;x-amz-date";
        String text = "";
        String payloadHash = DigestUtils.sha256Hex(text);
        String canonicalRequest = "GET\n/\n" + canonicalQueryString + "\n" + canonicalHeaders + "\n" + signedHeaders + "\n" + payloadHash;
        String credentialScope = String.format("%s/%s/ec2/aws4_request", dateStamp, this.region);
        
        String output = "";
        
        try {
            byte[] signingKey = getSignatureKey(this.secretKey, dateStamp, this.region, "ec2");
            String canonicalRequestHash = DigestUtils.sha256Hex(canonicalRequest);
            String stringToSign = String.format("AWS4-HMAC-SHA256\n%s\n%s\n%s", amazonDate, credentialScope, canonicalRequestHash);
            Mac sha256_HMAC = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretkey = new SecretKeySpec(signingKey, "HmacSHA256");
            sha256_HMAC.init(secretkey);
            byte[] hash = sha256_HMAC.doFinal(stringToSign.getBytes());
            String signature = Hex.encodeHexString(hash);
            String authorizationHeader = String.format("AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=host;x-amz-date, Signature=%s", this.accessKey, credentialScope, signature);
            String url = String.format("%s?%s", this.endpoint, canonicalQueryString);
            
            HttpClient client = new DefaultHttpClient();
            HttpGet get = new HttpGet(url);
            get.setHeader("Content-Type", "application/x-www-form-urlencoded");
            get.setHeader("x-amz-date", amazonDate);
            get.setHeader("Authorization", authorizationHeader);

            HttpResponse response;

            try {
                response = client.execute(get);
                HttpEntity entity = response.getEntity();
                output = EntityUtils.toString(entity);
            } 
            catch (IOException e) {
                throw new BridgeError("Unable to make a connection to properly execute the query to Amazon EC2");
            }
        
        } catch (Exception ex) {
            throw new BridgeError("Unable to make a connection to properly execute the query to Amazon EC2");
        }
        
        JSONObject jsonOutput = XML.toJSONObject(output);
        JSONObject reservationSet = jsonOutput.getJSONObject("DescribeInstancesResponse").getJSONObject("reservationSet");
        JSONArray outputArray = reservationSet.optJSONArray("item");
        // Check for the case where item isn't a JSON Array and has either 0 or 1 objects
        if (outputArray == null) {
            outputArray = new JSONArray();
            JSONObject item = reservationSet.optJSONObject("item");
            if (item != null) outputArray.put(item);
        }
        
        Pattern pattern = Pattern.compile("([\"\"])(?:(?=(\\\\?))\\2.)*?\\1");
        Matcher matcher = pattern.matcher(query);
        
        // Query is case sensitive
        while (matcher.find()) {
            String key = matcher.group();
            // used to replace the outside quotes from the key value
            key = key.replaceAll("^\"|\"$", "");
            if (!key.equals("*")) {
                // While there is still a value contained within double quotes
                matcher.find();
                String value = matcher.group();
                // used to replace the outside quotes from the value
                value = value.replaceAll("^\"|\"$", "");
                
                // Array to get the index of jsonObject that doesn't match
                // the query. This will help when we remove from jsonOutput
                // as elements shift.
                List<Integer> indices = new ArrayList<Integer>();

                for (int i = 0; i < outputArray.length(); i++) {
                    if (outputArray.getJSONObject(i).getJSONObject("instancesSet").optJSONObject("item") instanceof JSONObject) {
                        String rec = outputArray.getJSONObject(i).getJSONObject("instancesSet").getJSONObject("item").getString("instanceId");
                        if (!value.equals(rec)) {
                            indices.add(i);
                        }
                    } else {
                        indices.add(i);
                    }
                }

                Collections.sort(indices, Collections.reverseOrder());
                for (int i : indices) {
                    outputArray.remove(i);
                }
            }
        }

        Record record;
        
        if (outputArray.length() > 1) {
            throw new BridgeError("Multiple results matched an expected single match query");
        } else if (outputArray.length() == 0) {
            record = new Record(null);
        } else {
            JSONObject result = outputArray.getJSONObject(0);
            Map<String,Object> recordMap = new LinkedHashMap<String,Object>();
            if (fields == null) {
                record = new Record(null);
            } else {
                for (String field: fields) {
                    recordMap.put(field, result.getJSONObject("instancesSet").getJSONObject("item").getString(field));
                }
                record = new Record(recordMap);
            }
        }
        
        // Retrieve fields that are contained in a json string
        record = BridgeUtils.getNestedFields(request.getFields(),Arrays.asList(record)).get(0);
        
        return record;
    }

    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        String structure = request.getStructure();
        List<String> fields = request.getFields();
        Map<String,String> metadata = BridgeUtils.normalizePaginationMetadata(request.getMetadata());
        AmazonEC2QualificationParser parser = new AmazonEC2QualificationParser();
        String query = parser.parse(request.getQuery(),request.getParameters());
        
        TimeZone tz = TimeZone.getTimeZone("UTC");
        DateFormat df = new SimpleDateFormat("yyyyMMdd'T'HHmmss");
        df.setTimeZone(tz);
        final String amazonDate = df.format(new Date()) + "Z";
        
        DateFormat ds = new SimpleDateFormat("yyyyMMdd");
        ds.setTimeZone(tz);
        String dateStamp = ds.format(new Date());
        String canonicalQueryString = String.format("Action=%s&Version=%s", this.action, this.apiVersion);
        String canonicalHeaders = String.format("host:%s\nx-amz-date:%s\n", this.host, amazonDate);
        String signedHeaders = "host;x-amz-date";
        String text = "";
        String payloadHash = DigestUtils.sha256Hex(text);
        String canonicalRequest = "GET\n/\n" + canonicalQueryString + "\n" + canonicalHeaders + "\n" + signedHeaders + "\n" + payloadHash;
        String credentialScope = String.format("%s/%s/ec2/aws4_request", dateStamp, this.region);
        
        String output = "";
        
        try {
            byte[] signingKey = getSignatureKey(this.secretKey, dateStamp, this.region, "ec2");
            String canonicalRequestHash = DigestUtils.sha256Hex(canonicalRequest);
            String stringToSign = String.format("AWS4-HMAC-SHA256\n%s\n%s\n%s", amazonDate, credentialScope, canonicalRequestHash);
            Mac sha256_HMAC = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretkey = new SecretKeySpec(signingKey, "HmacSHA256");
            sha256_HMAC.init(secretkey);
            byte[] hash = sha256_HMAC.doFinal(stringToSign.getBytes());
            String signature = Hex.encodeHexString(hash);
            String authorizationHeader = String.format("AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=host;x-amz-date, Signature=%s", this.accessKey, credentialScope, signature);
            String url = String.format("%s?%s", this.endpoint, canonicalQueryString);
            
            HttpClient client = new DefaultHttpClient();
            HttpGet get = new HttpGet(url);
            get.setHeader("Content-Type", "application/x-www-form-urlencoded");
            get.setHeader("x-amz-date", amazonDate);
            get.setHeader("Authorization", authorizationHeader);

            HttpResponse response;

            try {
                response = client.execute(get);
                HttpEntity entity = response.getEntity();
                output = EntityUtils.toString(entity);
            } 
            catch (IOException e) {
                throw new BridgeError("Unable to make a connection to properly execute the query to Amazon EC2");
            }
        
        } catch (Exception ex) {
            throw new BridgeError("Unable to make a connection to properly execute the query to Amazon EC2");
        }
        
        JSONObject jsonOutput = XML.toJSONObject(output);
        JSONObject reservationSet = jsonOutput.getJSONObject("DescribeInstancesResponse").getJSONObject("reservationSet");
        JSONArray outputArray = reservationSet.optJSONArray("item");
        // Check for the case where item isn't a JSON Array and has either 0 or 1 objects
        if (outputArray == null) {
            outputArray = new JSONArray();
            JSONObject item = reservationSet.optJSONObject("item");
            if (item != null) outputArray.put(item);
        }
        
        Pattern pattern = Pattern.compile("([\"\"])(?:(?=(\\\\?))\\2.)*?\\1");
        Matcher matcher = pattern.matcher(query);
        
        // Query is case sensitive
        while (matcher.find()) {
            String key = matcher.group();
            // used to replace the outside quotes from the key value
            key = key.replaceAll("^\"|\"$", "");
            if (!key.equals("*")) {
                // While there is still a value contained within double quotes
                matcher.find();
                String value = matcher.group();
                // used to replace the outside quotes from the value
                value = value.replaceAll("^\"|\"$", "");
                
                // Array to get the index of jsonObject that doesn't match
                // the query. This will help when we remove from jsonOutput
                // as elements shift.
                List<Integer> indices = new ArrayList<Integer>();

                for (int i = 0; i < outputArray.length(); i++) {
                    if (outputArray.getJSONObject(i).getJSONObject("instancesSet").optJSONObject("item") instanceof JSONObject) {
                        String rec = outputArray.getJSONObject(i).getJSONObject("instancesSet").getJSONObject("item").getString(key);
                        if (!value.equals(rec)) {
                            indices.add(i);
                        }
                    } else {
                        indices.add(i);
                    }
                }

                Collections.sort(indices, Collections.reverseOrder());
                for (int i : indices) {
                    outputArray.remove(i);
                }
            }
        }

        List<Record> records = new ArrayList<Record>();
        
        for (int i=0; i < outputArray.length(); i++) {
            Map<String,Object> map = new HashMap<String,Object>();
            if (outputArray.getJSONObject(i).getJSONObject("instancesSet").optJSONObject("item") instanceof JSONObject) {
                JSONObject recordObject = (JSONObject)outputArray.getJSONObject(i).getJSONObject("instancesSet").getJSONObject("item");
                Iterator<String> keysItr = recordObject.keys();
                while(keysItr.hasNext()) {
                    String key = keysItr.next();
                    Object value = recordObject.get(key);
                    if (value instanceof org.json.JSONObject) value = value.toString();
                    map.put(key, value);
                }
            }
            records.add(new Record(map));
        }
        
        // Retrieve fields from a json string
        records = BridgeUtils.getNestedFields(request.getFields(), records);

        // Returning the response
        return new RecordList(fields, records, metadata);
    }
    
    static byte[] HmacSHA256(String data, byte[] key) throws Exception  {
        String algorithm="HmacSHA256";
        Mac mac = Mac.getInstance(algorithm);
        mac.init(new SecretKeySpec(key, algorithm));
        return mac.doFinal(data.getBytes("UTF8"));
    }

    static byte[] getSignatureKey(String key, String dateStamp, String regionName, String serviceName) throws Exception  {
         byte[] kSecret = ("AWS4" + key).getBytes("UTF8");
         byte[] kDate    = HmacSHA256(dateStamp, kSecret);
         byte[] kRegion  = HmacSHA256(regionName, kDate);
         byte[] kService = HmacSHA256(serviceName, kRegion);
         byte[] kSigning = HmacSHA256("aws4_request", kService);
         return kSigning;
    }
 
}