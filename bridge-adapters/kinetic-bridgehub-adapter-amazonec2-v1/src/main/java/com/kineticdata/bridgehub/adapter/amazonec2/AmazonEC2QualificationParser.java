package com.kineticdata.bridgehub.adapter.amazonec2;

import com.kineticdata.bridgehub.adapter.QualificationParser;

public class AmazonEC2QualificationParser extends QualificationParser {
    public String encodeParameter(String name, String value) {
        return value;
    }
}
