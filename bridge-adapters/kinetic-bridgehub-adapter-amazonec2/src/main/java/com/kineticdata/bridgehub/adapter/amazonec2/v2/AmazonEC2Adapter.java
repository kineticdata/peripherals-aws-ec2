package com.kineticdata.bridgehub.adapter.amazonec2.v2;

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
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URLEncoder;
import java.util.Date;
import java.util.Map;
import java.util.TimeZone;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.apache.commons.codec.binary.Hex;
import org.apache.commons.codec.digest.*;
import org.apache.commons.lang.StringUtils;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;
import org.json.XML;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.simple.JSONValue;
import org.slf4j.LoggerFactory;


public class AmazonEC2Adapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/
    
    /** Defines the adapter display name */
    public static final String NAME = "Amazon EC2 Bridge";
    
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
        public static final String REGION = "Region";
        public static final String API_VERSION = "API Version";
    }
    
    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
        new ConfigurableProperty(Properties.ACCESS_KEY).setIsRequired(true),
        new ConfigurableProperty(Properties.SECRET_KEY).setIsRequired(true).setIsSensitive(true),
        new ConfigurableProperty(Properties.REGION).setIsRequired(true)
    );
    
    private String accessKey;
    private String secretKey;
    private String region;
    
    /*---------------------------------------------------------------------------------------------
     * SETUP METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public void initialize() throws BridgeError {
        this.accessKey = properties.getValue(Properties.ACCESS_KEY);
        this.secretKey = properties.getValue(Properties.SECRET_KEY);
        this.region = properties.getValue(Properties.REGION);
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
        AmazonEC2QualificationParser parser = new AmazonEC2QualificationParser();
        String query = parser.parse(request.getQuery(),request.getParameters());
        
        // Build the url to retrieve the ec2 data
        StringBuilder url = new StringBuilder("https://ec2.amazonaws.com");
        url.append("?Version=2016-11-15&Action=Describe").append(request.getStructure());
        if (!query.isEmpty()) url.append("&").append(parser.convertToAwsSyntax(query));
        
        // The headers that we want to add to the request
        List<String> headers = new ArrayList<String>();
        
        // Make the request using the built up url/headers and bridge properties
        HttpResponse response = request(url.toString(),headers,this.region,this.accessKey,this.secretKey);
        String output;
        try {
            output = EntityUtils.toString(response.getEntity());
        } catch (IOException e) { throw new BridgeError(e); }
        
        if (response.getStatusLine().getStatusCode() != 200) throwParsedError(output, request.getStructure());
        JSONObject jsonObject = responseToJsonObject(output, request.getStructure());
        
        // DescribeInstances is a special case because of the reservationSet//instancesSet return
        // structure, so for those we are going to call the helper method to turn the JSON into
        // a recordObject list so that we can count instances, not reservations
        int count = 0;
        if (request.getStructure().equals("Instances")) {
             count = convertJsonToRecordObjects(jsonObject).size();
        } else {
            Object item = jsonObject.get("item");
            if (item instanceof JSONObject) {
                count = 1;
            } else if (item instanceof JSONArray) {
                count = ((JSONArray) item).length();
            }
        }

        return new Count(count);
    }

    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {
        AmazonEC2QualificationParser parser = new AmazonEC2QualificationParser();
        String query = parser.parse(request.getQuery(),request.getParameters());
        
        // Build the url to retrieve the ec2 data
        StringBuilder url = new StringBuilder("https://ec2.amazonaws.com");
        url.append("?Version=2016-11-15&Action=Describe").append(request.getStructure());
        if (!query.isEmpty()) url.append("&").append(parser.convertToAwsSyntax(query));
        
        // The headers that we want to add to the request
        List<String> headers = new ArrayList<String>();
        
        // Make the request using the built up url/headers and bridge properties
        HttpResponse response = request(url.toString(),headers,this.region,this.accessKey,this.secretKey);
        String output;
        try {
            output = EntityUtils.toString(response.getEntity());
        } catch (IOException e) { throw new BridgeError(e); }
        
        // Get the JSONObject from the XML Response
        if (response.getStatusLine().getStatusCode() != 200) throwParsedError(output, request.getStructure());
        JSONObject jsonObject = responseToJsonObject(output, request.getStructure());
        
        // Convert the JSONObject to a List of Record Objects
        List<Map<String,Object>> recordObjects = convertJsonToRecordObjects(jsonObject);
        
        Record record;
        if (recordObjects.size() > 1) {
            throw new BridgeError("Multiple results matched an expected single match query");
        } else if (recordObjects.isEmpty()) {
            record = new Record(null);
        } else {
            if (request.getFields() == null || request.getFields().isEmpty()) {
                record = new Record(recordObjects.get(0));
            } else {
                Map<String,Object> recordObject = new LinkedHashMap<String,Object>();
                for (String field : request.getFields()) {
                    recordObject.put(field, recordObjects.get(0).get(field));
                }
                record = new Record(recordObject);
            }
        }
        
        return record;
    }

    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        AmazonEC2QualificationParser parser = new AmazonEC2QualificationParser();
        String query = parser.parse(request.getQuery(),request.getParameters());
        
        // Build the url to retrieve the ec2 data
        StringBuilder url = new StringBuilder("https://ec2.amazonaws.com");
        url.append("?Version=2016-11-15&Action=Describe").append(request.getStructure());
        if (!query.isEmpty()) url.append("&").append(parser.convertToAwsSyntax(query));
        
        // The headers that we want to add to the request
        List<String> headers = new ArrayList<String>();
        
        // Make the request using the built up url/headers and bridge properties
        HttpResponse response = request(url.toString(),headers,this.region,this.accessKey,this.secretKey);
        String output;
        try {
            output = EntityUtils.toString(response.getEntity());
        } catch (IOException e) { throw new BridgeError(e); }
        
        // Get the JSONObject from the XML Response
        if (response.getStatusLine().getStatusCode() != 200) throwParsedError(output, request.getStructure());
        JSONObject jsonObject = responseToJsonObject(output, request.getStructure());
        
        // Convert the JSONObject to a List of Record Objects
        List<Map<String,Object>> recordObjects = convertJsonToRecordObjects(jsonObject);
        
        // Define the fields - if not fields were passed, set they keySet of the a returned objects as
        // the field set
        List<String> fields = request.getFields();
        if ((fields == null || fields.isEmpty()) && !recordObjects.isEmpty()) fields = new ArrayList<String>(recordObjects.get(0).keySet());
        
        // Define the metadata
        Map<String,String> metadata = new LinkedHashMap<String,String>();
        metadata.put("size",String.valueOf(recordObjects.size()));
        metadata.put("nextPageToken",null);
        
        // Convert the List of record objects to a list of records
        List<Record> records = new ArrayList<Record>();
        for (Map<String,Object> recordObject : recordObjects) {
            records.add(new Record(recordObject));
        }
        
        records = BridgeUtils.getNestedFields(fields, records);

        // Returning the response
        return new RecordList(fields, records, metadata);
    }
    
    /*----------------------------------------------------------------------------------------------
     * HELPER METHODS
     *--------------------------------------------------------------------------------------------*/
    /**
     * This method builds and sends a request to the Amazon EC2 REST API given the inputted
     * data and return a HttpResponse object after the call has returned. This method mainly helps with
     * creating a proper signature for the request (documentation on the Amazon REST API signing
     * process can be found here - http://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html),
     * but it also throws and logs an error if a 401 or 403 is retrieved on the attempted call.
     * 
     * @param url
     * @param headers
     * @param region
     * @param accessKey
     * @param secretKey
     * @return
     * @throws BridgeError 
     */
    private HttpResponse request(String url, List<String> headers, String region, String accessKey, String secretKey) throws BridgeError {
        // Build a datetime timestamp of the current time (in UTC). This will be sent as a header
        // to Amazon and the datetime stamp must be within 5 minutes of the time on the
        // recieving server or else the request will be rejected as a 403 Forbidden
        DateFormat df = new SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'");
        df.setTimeZone(TimeZone.getTimeZone("UTC"));
        String datetime = df.format(new Date());
        String date = datetime.split("T")[0];
        
        // Create a URI from the request URL so that we can pull the host/path/query from it
        URI uri;
        try {
            uri = new URI(url);
        } catch (URISyntaxException e) {
            throw new BridgeError("There was an error parsing the inputted url '"+url+"' into a java URI.",e);
        }
        
        /* BUILD CANONCIAL REQUEST (uri, query, headers, signed headers, hashed payload)*/
        
        // Canonical URI (the part of the URL between the host and the ?. If blank, the uri is just /)
        String canonicalUri = uri.getPath().isEmpty() ? "/" : uri.getPath();
        
        // Canonical Query (parameter names sorted by asc and param names and values escaped
        // and trimmed)
        String canonicalQuery;
        // Trim the param names and values and load the parameters into a map
        Map<String,String> queryMap = new HashMap<String,String>();
        for (String parameter : uri.getQuery().split("&")) {
            queryMap.put(parameter.split("=")[0].trim(), parameter.split("=")[1].trim());
        }
        
        StringBuilder queryBuilder = new StringBuilder();
        for (String key : new TreeSet<String>(queryMap.keySet())) {
            if (!queryBuilder.toString().isEmpty()) queryBuilder.append("&");
            queryBuilder.append(URLEncoder.encode(key)).append("=").append(URLEncoder.encode(queryMap.get(key)));
        }
        canonicalQuery = queryBuilder.toString();
        
        // Canonical Headers (lowercase and sort headers, add host and date headers if they aren't
        // already included, then create a header string with trimmed name and values and a new line
        // character after each header - including the last one)
        String canonicalHeaders;
        // Lowercase/trim each header and header value and load into a map
        Map<String,String> headerMap = new HashMap<String,String>();
        for (String header : headers) {
            headerMap.put(header.split(":")[0].toLowerCase().trim(), header.split(":")[1].toLowerCase().trim());
        }
        // If the date and host headers aren't already in the header map, add them
        if (!headerMap.keySet().contains("host")) headerMap.put("host",uri.getHost());
        if (!headerMap.keySet().contains("x-amz-date")) headerMap.put("x-amz-date",datetime);
        // Sort the headers and append a newline to the end of each of them
        StringBuilder headerBuilder = new StringBuilder();
        for (String key : new TreeSet<String>(headerMap.keySet())) {
            headerBuilder.append(key).append(":").append(headerMap.get(key)).append("\n");
        }
        canonicalHeaders = headerBuilder.toString();
        
        // Signed Headers (a semicolon separated list of heads that were signed in the previous step)
        String signedHeaders = StringUtils.join(new TreeSet<String>(headerMap.keySet()),";");
        
        // Hashed Payload (a SHA256 hexdigest with the request payload - because the bridge only
        // does GET requests the payload will always be an empty string)
        String hashedPayload = DigestUtils.sha256Hex("");
        
        // Canonical Request (built out of 6 parts - the request method and the previous 5 steps in order
        // - with a newline in between each step and then a SHA256 hexdigest run on the resulting string)
        StringBuilder requestBuilder = new StringBuilder();
        requestBuilder.append("GET").append("\n");
        requestBuilder.append(canonicalUri).append("\n");
        requestBuilder.append(canonicalQuery).append("\n");
        requestBuilder.append(canonicalHeaders).append("\n");
        requestBuilder.append(signedHeaders).append("\n");
        requestBuilder.append(hashedPayload);
        // Run the resulting string through a SHA256 hexdigest
        String canonicalRequest = DigestUtils.sha256Hex(requestBuilder.toString());
        
        /* BUILD STRING TO SIGN (credential scope, string to sign) */
        
        // Credential Scope (date, region, service, and terminating string [which is always aws4_request)
        String credentialScope = String.format("%s/%s/%s/aws4_request",date,region,"ec2");
        
        // String to Sign (encryption method, datetime, credential scope, and canonical request)
        StringBuilder stringToSignBuilder = new StringBuilder();
        stringToSignBuilder.append("AWS4-HMAC-SHA256").append("\n");
        stringToSignBuilder.append(datetime).append("\n");
        stringToSignBuilder.append(credentialScope).append("\n");
        stringToSignBuilder.append(canonicalRequest);
        String stringToSign = stringToSignBuilder.toString();
        
        /* CREATE THE SIGNATURE (signing key, signature) */
        
        // Signing Key
        byte[] signingKey;
        try {
            signingKey = getSignatureKey(secretKey,date,region,"ec2");
        } catch (Exception e) {
            throw new BridgeError("There was a problem creating the signing key",e);
        }
        
        // Signature
        String signature;
        try {
            signature = Hex.encodeHexString(HmacSHA256(signingKey,stringToSign));
        } catch (Exception e) {
            throw new BridgeError("There was a problem creating the signature",e);
        }
        
        // Authorization Header (encryption method, access key, credential scope, signed headers, signature))
        String authorization = String.format("AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s",accessKey,credentialScope,signedHeaders,signature);
        
        /* CREATE THE HTTP REQUEST */
        HttpClient client = HttpClients.createDefault();
        HttpGet get = new HttpGet(url);
        get.setHeader("Authorization",authorization);
        for (Map.Entry<String,String> header : headerMap.entrySet()) {
            get.setHeader(header.getKey(),header.getValue());
        }
        
        HttpResponse response;
        try {
            response = client.execute(get);
            
            if (response.getStatusLine().getStatusCode() == 401 || response.getStatusLine().getStatusCode() == 403) {
                logger.error(EntityUtils.toString(response.getEntity()));
                throw new BridgeError("User not authorized to access this resource. Check the logs for more details.");
            }
        } catch (IOException e) { throw new BridgeError(e); }
        
        return response;
    }
    
    private void throwParsedError(String output, String structure) throws BridgeError {
        JSONObject convertedJson = XML.toJSONObject(output);
        try {
            JSONObject error = convertedJson.getJSONObject("Response").getJSONObject("Errors").getJSONObject("Error");
            if (error.getString("Code").equals("InvalidAction")) {
                throw new BridgeError(String.format("Invalid Structure: '%s' is not a valid structure. 'Describe%s' is not a valid Action in the EC2 API",structure,structure));
            } else {
                throw new BridgeError(error.toString());
            }
        } catch (JSONException e) {
            logger.debug(output);
            throw new BridgeError("An error occurred while attempting to convert the XML Response to JSON",e);
        }
    }
    
    private JSONObject responseToJsonObject(String output, String structure) throws BridgeError {
        JSONObject convertedJson = XML.toJSONObject(output);
        JSONObject returnJson = new JSONObject();
        try {
            JSONObject describeResponse = (JSONObject)convertedJson.getJSONObject("Describe"+structure+"Response");

            // Instance is a special case because all the instances are wrapped in reservationSets
            if (structure.equals("Instances")) {
                // Start by iterating through the reservation sets
                Object reservationSet = describeResponse.get("reservationSet");
                // If the reservationSet isn't an instance of JSONObject, that means that no items were
                // returned so it should return the empty array for items
                Object reservationSetItems = reservationSet instanceof JSONObject ? ((JSONObject)reservationSet).get("item") : null;
                JSONArray items = new JSONArray();
                if (reservationSetItems instanceof JSONObject) {
                    // If reservation set item is an object, that means 1 reservation set was returned
                    JSONObject instancesSet = ((JSONObject) reservationSetItems).getJSONObject("instancesSet");
                    items.put(items.length(),injectKeyValuePairIntoSet(instancesSet.get("item"), "reservationId",((JSONObject) reservationSetItems).getString("reservationId")));
                } else if (reservationSetItems instanceof JSONArray) {
                    // If reservation set item is an array, that means multiple reservation sets were returned
                    int reservationSetLength = ((JSONArray) reservationSetItems).length();
                    for (int i = 0; i < reservationSetLength; i++) {
                        JSONObject reservationItem = ((JSONArray) reservationSetItems).getJSONObject(i);
                        Object item = injectKeyValuePairIntoSet(reservationItem.getJSONObject("instancesSet").get("item"), "reservationId", reservationItem.getString("reservationId"));
                        if (item instanceof JSONObject) {
                            items.put(items.length(),item);
                        } else if (item instanceof JSONArray) {
                            int itemLen = ((JSONArray)item).length();
                            for (int j=0; j < itemLen; j++) {
                                items.put(items.length(),((JSONArray) item).get(j));
                            }
                        }
                    }
                }
                returnJson.put("item",items);
            } else {
                // Check the keys for the JSON Object and see if there are any that match
                // a name similar to the structure appended with set or info
                Set<String> keys = describeResponse.keySet();
                String structureKey = null;
                String structureNameCheck = structure;

                // To deal with amazon not being consistent with plural/singular on request vs return field,
                // if the structure ends with a s, remove it from the name check string
                if (structureNameCheck.endsWith("s")) structureNameCheck = structureNameCheck.substring(0,structureNameCheck.length()-1);
                for (String key : keys) {
                    // If key includes the string 'set' or 'info' and also includes the structure name, then it
                    // can be assumed that it is the list of the objects that you want to return
                    if (key.toLowerCase().contains(structureNameCheck) && (key.toLowerCase().contains("set") || key.toLowerCase().contains("info"))) {
                        structureKey = key;
                        break;
                    }
                }
                // If the structureKey is still null, then just look for any key that has set or info in the name
                if (structureKey == null) {
                    for (String key : keys) {
                        if (key.toLowerCase().contains("set") || key.toLowerCase().contains("info")) {
                            structureKey = key;
                            break;
                        }
                    }
                }
                // If the structureKey is still null, then assume the object returned is just a single object
                if (structureKey == null) {
                    returnJson =  describeResponse;
                } else {
                    Object returnObject = describeResponse.get(structureKey);
                    if (returnObject instanceof JSONObject) {
                        returnJson = (JSONObject)returnObject;
                    } else {
                        // If the returned object isn't a JSONObject, it is assumed that it returned a blank value
                        returnJson = null;
                    }
                }
            }
        
        } catch (JSONException e) {
            logger.debug(output);
            throw new BridgeError("An error occurred while attempting to convert the XML Response to JSON",e);
        }
        
        return returnJson;
    }
    
    private Object injectKeyValuePairIntoSet(Object set, String key, String value) {
        Object injectedSet = set;
        if (injectedSet instanceof JSONObject) {
            // If a single JSON item is returned, inject the key/value pair into that object
            ((JSONObject) injectedSet).put(key, value);
        } else if (injectedSet instanceof JSONArray) {
            // If a JSON array is returned, interate through the array and inject the key/value pair
            // into each object
            int setSize = ((JSONArray)injectedSet).length();
            for (int i = 0; i < setSize; i++) {
                ((JSONObject) ((JSONArray) injectedSet).get(i)).put(key, value);
            }
        }
        
        return injectedSet;
    }
    
    private List<Map<String,Object>> convertJsonToRecordObjects(JSONObject set) {
        // Initialize the record list that will be returned
        List<Map<String,Object>> records = new ArrayList<Map<String,Object>>();

        if (set != null && set.has("item")) {
            Object item = set.get("item");
            JSONArray jsonArray;
            // If item is a JSONObject, a single item was returned
            if (item instanceof JSONObject) {
                jsonArray = new JSONArray();
                jsonArray.put(new JSONObject(item));
            }
            // If item is a JSONArray, it is a JSON array
            else if (item instanceof JSONArray) {
                jsonArray = (JSONArray)item;
            } 
            // If not, it is a string and an empty list was returned
            else {
                jsonArray = new JSONArray();
            }

            int len = jsonArray.length();
            for (int i = 0; i < len; i++) {
                Map<String,Object> record = new HashMap<String,Object>();
                JSONObject jsonObject = (JSONObject)jsonArray.get(i);
                Set<String> jsonKeys = jsonObject.keySet();
                for (String key : jsonKeys) {
                    Object value = jsonObject.get(key);
                    if (value instanceof JSONObject && ((JSONObject)value).keySet().contains("item")) {
                        record.put(key, new ArrayList<JSONObject>());
                        for (Map<String,Object> m : convertJsonToRecordObjects((JSONObject)value)) {
                            ((ArrayList)record.get(key)).add(new JSONObject(m));
                        }
//                        record.put(key, convertJsonToRecordObjects((JSONObject)value));
                    } else if (value instanceof JSONObject) {
                        // If the value is a JSON object and isn't an item, convert it from JSONObject type org.json to
                        // org.json.simple so that it is serializable
                        record.put(key,JSONValue.parse(((JSONObject)value).toString()));
                    } else {
                        record.put(key, value);
                    }
                }
                records.add(record);
            }
        }
        // If the set is a single item
        else if (set != null) {
            Set<String> jsonKeys = set.keySet();
            Map<String,Object> record = new HashMap<String,Object>();
            for (String key : jsonKeys) {
                Object value = set.get(key);
                if (value instanceof JSONObject && ((JSONObject)value).keySet().contains("item")) {
                    record.put(key, convertJsonToRecordObjects((JSONObject)value));
                } else if (value instanceof JSONObject) {
                    // If the value is a JSON object and isn't an item, convert it from JSONObject type org.json to
                    // org.json.simple so that it is serializable
                    record.put(key,JSONValue.parse(((JSONObject)value).toString()));
                } else {
                    record.put(key, value);
                }
            }
            records.add(record);
        }
        
        return records;
    }
    
    static byte[] HmacSHA256(byte[] key, String data) throws Exception {
        String algorithm = "HmacSHA256";
        Mac mac = Mac.getInstance(algorithm);
        mac.init(new SecretKeySpec(key, algorithm));
        return mac.doFinal(data.getBytes("UTF8"));
    }

    static byte[] getSignatureKey(String secretKey, String date, String region, String service) throws Exception  {
         byte[] kSecret = ("AWS4" + secretKey).getBytes("UTF8");
         byte[] kDate    = HmacSHA256(kSecret, date);
         byte[] kRegion  = HmacSHA256(kDate, region);
         byte[] kService = HmacSHA256(kRegion, service);
         byte[] kSigning = HmacSHA256(kService, "aws4_request");
         return kSigning;
    }
 
}