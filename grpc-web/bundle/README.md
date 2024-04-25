# Apigee X Protobuf Decoder Java Callout

This is a sample Apigee X API Proxy that shows how to decode binary gRPC payloads from request and response messages.

In Apigee X, there is no out-of-the-box policy that supports inspecting gRPC messages. This proxy uses an [Apigee Java Callout policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/java-callout-policy)
to decode the gRPC messages, and encode them as JSON. This is useful if you want to apply policies that need to perform
some action based on the gRPC payload.

## How it works

The API Proxy uses a generic Java Callout policy that takes both the gRPC message, and a boolean to determine if the message is base64 encoded.
The output of the Java callout policy is a new flow variable named `pb-decoder.message-data`.

Below is an example XML snippet for how to execute the Java Callout policy:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<JavaCallout continueOnError="false" enabled="true" name="Java-ProtoDecode">
    <DisplayName>Java-ProtoDecode</DisplayName>
    <Properties>
        <Property name="pb-message-ref">request</Property>
        <Property name="pb-message-is-base64">true</Property>
    </Properties>
    <ClassName>com.google.apigee.callouts.ProtobufDecoder</ClassName>
    <ResourceURL>java://apigee-callout-protobuf-decoder.jar</ResourceURL>
</JavaCallout>
```

The following properties can be set as inputs for the Java Callout.

* **pb-message-ref** (required) - This is the name of the flow variable that contains the gRPC message. (only `request` or `response` is supported).
  This also determines which protobuf message type is used for decoding the gRPC binary payload.
  If you choose `request`, it uses the request message type of the gRPC service method being invoked.
  If you choose `response`, it uses the response message type of the gRPC service method being invoked.

* **pb-message-is-base64** (optional)- This specified whether the protobuf payload itself is base64 encoded on the wire
  For grpc-web, this should be set to `true`, otherwise omit this property, or set to `false`
