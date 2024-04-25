// Copyright 2024 Google LLC
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

package com.google.apigee.callouts;

import com.apigee.flow.execution.ExecutionContext;
import com.apigee.flow.execution.ExecutionResult;
import com.apigee.flow.execution.spi.Execution;
import com.apigee.flow.message.Message;
import com.apigee.flow.message.MessageContext;
import com.google.apigee.callouts.util.Debug;
import com.google.apigee.callouts.util.VarResolver;
import com.google.protobuf.DescriptorProtos;
import com.google.protobuf.Descriptors;
import com.google.protobuf.DynamicMessage;
import com.google.protobuf.TextFormat;
import com.google.protobuf.UnknownFieldSet;
import com.google.protobuf.DescriptorProtos.FileDescriptorSet;
import com.google.protobuf.Descriptors.FileDescriptor;
import com.google.protobuf.util.JsonFormat;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class ProtobufDecoder implements Execution {
    public static final String CALLOUT_VAR_PREFIX = "pb-decoder";
    public static final int PAYLOAD_OFFSET = 5;
    public static final String PROCESS_REQUEST = "request";
    public static final String PROCESS_RESPONSE = "response";
    public static final String PROP_MSG_REF = "pb-message-ref";
    public static final String PROP_SERVICE_METHOD_REF = "pb-service-method-ref";
    public static final String PROP_DESCRIPTOR_BASE64_REF = "pb-descriptor-base64-ref";
    public static final String PROP_DECODED_MESSAGE_REF = "pb-decoded-message-ref";
    public static final String PB_MESSAGE_IS_BASE_64 = "pb-message-is-base64";
    private final Map properties;

    public ProtobufDecoder(Map properties) {
        this.properties = properties;
    }

    private void saveOutputs(MessageContext msgCtx, ByteArrayOutputStream stdoutOS, ByteArrayOutputStream stderrOS) {
        msgCtx.setVariable("pb-decoder.info.stdout", new String(stdoutOS.toByteArray(), StandardCharsets.UTF_8));
        msgCtx.setVariable("pb-decoder.info.stderr", new String(stderrOS.toByteArray(), StandardCharsets.UTF_8));
    }

    public Descriptors.FileDescriptor build(DescriptorProtos.FileDescriptorProto proto, Map<String, DescriptorProtos.FileDescriptorProto> protoMap) throws Descriptors.DescriptorValidationException {
        return this.build(proto, protoMap, new HashMap<>());
    }

    public Descriptors.FileDescriptor build(DescriptorProtos.FileDescriptorProto proto, Map<String, DescriptorProtos.FileDescriptorProto> protoMap, Map<String, Descriptors.FileDescriptor> buildCache) throws Descriptors.DescriptorValidationException {
        Descriptors.FileDescriptor cachedEntry = buildCache.get(proto.getName());
        if (cachedEntry != null) {
            return cachedEntry;
        } else {
            List<String> filesDependencyList = proto.getDependencyList();
            List<Descriptors.FileDescriptor> descDependencyList = new ArrayList<>();

            for (String fileDependency : filesDependencyList) {
                DescriptorProtos.FileDescriptorProto fileProto = protoMap.get(fileDependency);
                if (fileProto == null) {
                    throw new RuntimeException(String.format("proto dependency %s not found", fileDependency));
                }

                FileDescriptor fileDesc = this.build(fileProto, protoMap, buildCache);
                descDependencyList.add(fileDesc);
            }

            Descriptors.FileDescriptor fileDesc = FileDescriptor.buildFrom(proto, descDependencyList.toArray(new Descriptors.FileDescriptor[0]));
            buildCache.put(proto.getName(), fileDesc);
            return fileDesc;
        }
    }

    public Descriptors.MethodDescriptor getMethod(String descriptorBase64, String requestPath) throws IOException, Descriptors.DescriptorValidationException {
        if (descriptorBase64 == null || descriptorBase64.isEmpty()) {
            throw new RuntimeException("No protobuf descriptor provided");
        }

        if (requestPath == null || requestPath.isEmpty()) {
            throw new RuntimeException("No request path provided");
        }

        String[] requestPathParts = requestPath.split("/");
        if (requestPathParts.length < 2) {
            throw new RuntimeException("expected at least 2 path segments");
        }

        String methodName = requestPathParts[requestPathParts.length - 1];
        String pkgAndService = requestPathParts[requestPathParts.length - 2];
        String[] pkgAndServiceParts = pkgAndService.split("\\.");
        String serviceName = pkgAndServiceParts[pkgAndServiceParts.length - 1];
        byte[] descriptorBytes = Base64.getDecoder().decode(descriptorBase64.getBytes());
        DescriptorProtos.FileDescriptorSet set = FileDescriptorSet.parseFrom(descriptorBytes);
        Map<String, DescriptorProtos.FileDescriptorProto> serviceLookupMap = new HashMap<>();
        Map<String, DescriptorProtos.FileDescriptorProto> protoLookupMap = new HashMap<>();

        for (DescriptorProtos.FileDescriptorProto fileDescProto : set.getFileList()) {
            protoLookupMap.put(fileDescProto.getName(), fileDescProto);
            List<DescriptorProtos.ServiceDescriptorProto> serviceList = fileDescProto.getServiceList();

            for (DescriptorProtos.ServiceDescriptorProto serviceDescProto : serviceList) {
                serviceLookupMap.put(serviceDescProto.getName(), fileDescProto);
            }
        }

        if (!serviceLookupMap.containsKey(serviceName)) {
            throw new RuntimeException(String.format("service %s not found in proto", serviceName));
        }

        DescriptorProtos.FileDescriptorProto file = serviceLookupMap.get(serviceName);
        Descriptors.FileDescriptor fileDescriptor = this.build(file, protoLookupMap);
        Descriptors.ServiceDescriptor service = fileDescriptor.findServiceByName(serviceName);
        if (service == null) {
            throw new RuntimeException(String.format("could not find service named %s", serviceName));
        }

        Descriptors.MethodDescriptor method = service.findMethodByName(methodName);
        if (method == null) {
            throw new RuntimeException(String.format("could not find method named %s in service %s", methodName, serviceName));
        }

        return method;

    }


    String decodeAsText(InputStream inputStream, Boolean protoIsBase64, PrintStream stdout, PrintStream stderr) throws IOException {
        byte[] messageBytes = inputStream.readAllBytes();
        if (messageBytes.length == 0) {
            return "";
        }

        if (protoIsBase64 != null && protoIsBase64) {
            messageBytes = Base64.getDecoder().decode(messageBytes);
        }

        byte[] msgPayload = Arrays.copyOfRange(messageBytes, PAYLOAD_OFFSET, messageBytes.length);


        //stdout.println("message-length: " + msgPayload.length);
        UnknownFieldSet unknownFieldSet = UnknownFieldSet.parseFrom(msgPayload);
        return TextFormat.printer().printToString(unknownFieldSet);
    }

    String decodeAsJSON(InputStream inputStream, Boolean protoIsBase64, Descriptors.Descriptor descriptor, PrintStream stdout, PrintStream stderr) throws IOException, Descriptors.DescriptorValidationException {
        byte[] messageBytes = inputStream.readAllBytes();
        if (messageBytes.length == 0) {
            return "{}";
        }

        if (protoIsBase64 != null && protoIsBase64) {
            messageBytes = Base64.getDecoder().decode(messageBytes);
        }

        byte[] msgPayload = Arrays.copyOfRange(messageBytes, PAYLOAD_OFFSET, messageBytes.length);

        //stdout.println("message-length: " + msgPayload.length);
        DynamicMessage msg = DynamicMessage.parseFrom(descriptor, msgPayload);
        return JsonFormat.printer().print(msg);
    }

    public ExecutionResult execute(MessageContext messageContext, ExecutionContext executionContext) {
        ByteArrayOutputStream stdoutOS = new ByteArrayOutputStream();
        ByteArrayOutputStream stderrOS = new ByteArrayOutputStream();
        PrintStream stderr = null;
        PrintStream stdout = null;

        try {
            stdout = new PrintStream(stdoutOS, true, StandardCharsets.UTF_8.name());
            stderr = new PrintStream(stderrOS, true, StandardCharsets.UTF_8.name());
            VarResolver vars = new VarResolver(messageContext, this.properties);
            new Debug(messageContext, CALLOUT_VAR_PREFIX);
            String protoDescriptorBase64 = vars.getVar(vars.getProp(PROP_DESCRIPTOR_BASE64_REF));
            String protoServiceMethodPath = vars.getVar(vars.getProp(PROP_SERVICE_METHOD_REF));
            String protoDecodedMessageRef = vars.getProp(PROP_DECODED_MESSAGE_REF);
            String protoProcessMessage = vars.getProp(PROP_MSG_REF);
            Boolean protoMessageIsBase64 = "true".equals(vars.getProp(PB_MESSAGE_IS_BASE_64));

            Descriptors.MethodDescriptor method = null;

            Message msg;
            try {
                method = this.getMethod(protoDescriptorBase64, protoServiceMethodPath);
            } catch (Exception ex) {
                stdout.println("could not find protobuf service/method. " + ex.getMessage());
            }


            Descriptors.Descriptor desc;
            if (PROCESS_RESPONSE.equals(protoProcessMessage)) {
                msg = messageContext.getResponseMessage();
                desc = method == null ? null : method.getOutputType();
            } else {
                msg = messageContext.getRequestMessage();
                desc = method == null ? null : method.getInputType();
            }

            String decoded = null;

            try {
                if (desc == null) {
                    decoded = this.decodeAsText(msg.getContentAsStream(), protoMessageIsBase64, stdout, stderr);
                    messageContext.setVariable(String.format("%s.%s", CALLOUT_VAR_PREFIX, "message-format"), "text");
                } else {
                    decoded = this.decodeAsJSON(msg.getContentAsStream(), protoMessageIsBase64, desc, stderr, stderr);
                    messageContext.setVariable(String.format("%s.%s", CALLOUT_VAR_PREFIX, "message-format"), "json");
                }
            } catch (Exception ex) {
                stderr.println("could not decode protobuf. " + ex.getMessage());
            }

            if (decoded != null) {
                messageContext.setVariable(String.format("%s.%s", CALLOUT_VAR_PREFIX, "message-data"), decoded);
                if (protoDecodedMessageRef != null && !protoDecodedMessageRef.isEmpty()) {
                    messageContext.setVariable(protoDecodedMessageRef, decoded);
                }
            }

            return ExecutionResult.SUCCESS;
        } catch (Exception | Error ex) {
            ex.printStackTrace(stderr);
            return ExecutionResult.ABORT;
        } finally {
            this.saveOutputs(messageContext, stdoutOS, stderrOS);
        }

    }
}
