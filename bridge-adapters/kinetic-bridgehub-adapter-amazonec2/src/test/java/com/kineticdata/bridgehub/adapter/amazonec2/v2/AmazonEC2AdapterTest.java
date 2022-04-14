package com.kineticdata.bridgehub.adapter.amazonec2.v2;

import com.kineticdata.bridgehub.adapter.BridgeAdapterTestBase;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.Test;

import static org.junit.Assert.*;

public class AmazonEC2AdapterTest extends BridgeAdapterTestBase {

    @Override
    public String getConfigFilePath() {
        return "src/test/resources/bridge-config.yml";
    }

    @Override
    public Class getAdapterClass() {
        return AmazonEC2Adapter.class;
    }

    @Test
    public void test_search() {
        BridgeError error = null;

        BridgeRequest request = new BridgeRequest();
        request.setStructure("InstanceTypes");

        List<String> fields = new ArrayList<String>();
        request.setFields(fields);
        request.setQuery("");

        Map parameters = new HashMap();
        request.setParameters(parameters);

        RecordList list = null;
        try {
            list = getAdapter().search(request);
        } catch (BridgeError e) {
            error = e;
        }

        assertNull(error);
        assertTrue(list.getRecords().size() > 0);
    }

    @Test
    public void test_search_query() {
        BridgeError error = null;

        BridgeRequest request = new BridgeRequest();
        request.setStructure("Instances");

        List<String> fields = new ArrayList<String>();
        request.setFields(fields);
        request.setQuery("MaxResults=5");

        Map parameters = new HashMap();
        request.setParameters(parameters);

        RecordList list = null;
        try {
            list = getAdapter().search(request);
        } catch (BridgeError e) {
            error = e;
        }

        assertNull(error);
        assertEquals(list.getRecords().size(), 5);
    }

    @Test
    public void test_retrieve() {
        BridgeError error = null;

        BridgeRequest request = new BridgeRequest();
        request.setStructure("Instances");

        List<String> fields = new ArrayList<String>();
        request.setFields(fields);
        request.setQuery("instance-id=i-059439056ae48103c");

        Map parameters = new HashMap();
        request.setParameters(parameters);

        Record record = null;
        try {
            record = getAdapter().retrieve(request);
        } catch (BridgeError e) {
            error = e;
        }

        assertNull(error);
        assertTrue(record.getRecord().size() > 0);
    }
}