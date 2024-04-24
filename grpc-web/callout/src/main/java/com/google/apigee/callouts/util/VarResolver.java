// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.google.apigee.callouts.util;

import com.apigee.flow.message.MessageContext;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class VarResolver {
    MessageContext msgCtx;
    Map properties;

    public VarResolver(MessageContext msgCtx, Map properties) {
        this.msgCtx = msgCtx;
        this.properties = properties;
    }

    public String eval(String text) {
        if (isVarRef(text)) {
            return getVar(trimFirstAndLast(text));
        }

        return text;
    }

    private boolean isVarRef(String varName) {
        return varName.startsWith("{") && varName.endsWith("}");
    }

    private String trimFirstAndLast(String str) {
        if (str == null || str.length() < 2) {
            return str;
        }

        return str.substring(1, str.length() - 1);
    }

    public <T> T getVar(String varName, Class<T> clz, T defaultValue) {
        if (varName == null || varName.isEmpty()) {
            return defaultValue;
        }

        Object varValue = msgCtx.getVariable(varName);

        return tryConvert(varValue, clz, defaultValue);
    }

    private <T> T tryConvert(Object value, Class<T> clz, T defaultValue) {
        if (value == null) {
            return defaultValue;
        }

        if (clz.isAssignableFrom(value.getClass())) {
            return (T) value;
        }

        if (clz.equals(Boolean.class) &&  (value instanceof String) &&
                ("true".equalsIgnoreCase((String) value)) ||
                ("false".equalsIgnoreCase((String) value))) {
            return (T) Boolean.valueOf((String) value);
        }

        if (clz.equals(Integer.class) && (value instanceof String) &&
                ((String) value).matches("^[+-]?\\d+")) {
            return (T) Integer.valueOf((String) value);
        }

        if ((clz.equals(Float.class) || clz.equals(Double.class)) && (value instanceof String) &&
                ((String) value).matches("^[+-]?\\d+(.\\d+)?")) {
            return (T) Float.valueOf((String) value);
        }

        return defaultValue;
    }

    public <T> T getProp(String propertyName, Class<T> clz, T defaultValue) {
        Object propValue = properties.get(propertyName);
        if (propValue == null) {
            return defaultValue;
        }

        if (propValue instanceof String && isVarRef((String) propValue)) {
            String varName = trimFirstAndLast((String) propValue);
            return getVar(varName, clz, defaultValue);
        }

        if (propValue instanceof String) {
            String varValue = replaceAllRefs((String)propValue);

            return tryConvert(varValue, clz, defaultValue);

        }

        return tryConvert(propValue, clz, defaultValue);
    }

    public  String replaceAllRefs(String propValue) {
        String rx = "(\\{[a-zA-Z0-9-.]+\\})";

        StringBuffer sb = new StringBuffer();
        Pattern p = Pattern.compile(rx);
        Matcher m = p.matcher(propValue);

        while (m.find())
        {
            String varName =  trimFirstAndLast(m.group(1));

            String replacement = getVar(varName, String.class, "");
            if (replacement != null){
                m.appendReplacement(sb, replacement);
            }
        }
        m.appendTail(sb);

        return sb.toString();
    }

    public String getProp(String propName) {
        return getProp(propName, String.class, null);
    }

    public String getRequiredProp(String propName, String message) {
        String result = getProp(propName, String.class, null);
        if (result == null || result.isEmpty()) {
            throw new RuntimeException(propName + " is required." + message);
        }
        return result;
    }

    public String getVar(String varName) {
        return getVar(varName, String.class, null);
    }
}
