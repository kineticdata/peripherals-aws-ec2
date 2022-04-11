package com.kineticdata.bridgehub.adapter.amazonec2.v2;

import com.kineticdata.bridgehub.adapter.QualificationParser;
import static com.kineticdata.bridgehub.adapter.amazonec2.v2.AmazonEC2Adapter.logger;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.apache.commons.lang.StringUtils;

public class AmazonEC2QualificationParser extends QualificationParser {
    private static final Pattern FILTER_PATTERN = Pattern.compile("^([^A-Z]+)=(.*?)$");
    
    @Override
    public String encodeParameter(String name, String value) {
        return value;
    }
    
    /**
     * A method used to convert a method from a simpler syntax to the more complicated AWS syntax.
     * The main thing it does it take any lowercase field key and converts that to the Filter syntax. (ie.
     * instance-id=i-ae6cadd9a71861e80 changes to Filter.1.Name=instance-id&Filter1.Value=i-ae6cadd9a71861e80
     * while InstanceId.1=i-ae6cadd9a71861e80 doesn't get changed).
     * @param query
     * @return 
     */
    public String convertToAwsSyntax(String query) {
        logger.trace("Bridge Query Input: "+query);
        List<String> awsQuery = new ArrayList<String>();
        if (query != null && !query.isEmpty()) {
            int filterCount = 1;
            String[] parts = query.split("&");
            for (String q : parts) {
                Matcher m = FILTER_PATTERN.matcher(q);
                if (m.matches()) {
                    awsQuery.add("Filter."+String.valueOf(filterCount)+".Name="+m.group(1));
                    awsQuery.add("Filter."+String.valueOf(filterCount)+".Value="+m.group(2));
                } else {
                    awsQuery.add(q);
                }
            }
        }
        String result = StringUtils.join(awsQuery,"&");
        logger.trace("AWS Query Output: "+result);
        return result;
    }
}
