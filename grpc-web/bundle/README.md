# Apigee X Protobuf Decoder Java Callout

This is a sample Apigee X API Proxy that shows how to decode binary gRPC payloads from request and response messages.

In Apigee X, there is no out-of-the-box policy that supports inspecting gRPC messages. This proxy uses an [Apigee Java Callout policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/java-callout-policy)
to decode the gRPC messages, and encode them as JSON. This is useful if you want to apply policies that need to perform
some action based on the gRPC payload.

For this sample, the API Proxy is configured to invoke `language.googleapis.com` gRPC endpoint as the backend service.

## Caveat

As of October 2023, Apigee support for gRPC is in preview mode. Also, the [documentation](https://cloud.google.com/apigee/docs/api-platform/fundamentals/build-simple-api-proxy#creating-grpc-api-proxies)
explicitly says that the gRPC payloads are opaque to Apigee. However, form a Java Callout policy it is possible to retrieve the
binary payload and process it, which is what is being done in this example. Treat this example code as a proof-of-concept/experiment only.

## How it works

The API Proxy uses a generic Java Callout policy that takes both the gRPC message, and the protobuf descriptor as input.
The output of the Java callout policy is a new flow variable named `pb-decoder.message-json`.

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
