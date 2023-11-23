# Property Set

---
This sample shows how to easily define a Property Set and how to
access data from it.
This sample leverages the following policy:

* [Assign Message](https://cloud.google.com/apigee/docs/api-platform/reference/policies/assign-message-policy?hl=en) policy to set the JSON response with values retrieved from a [property set](https://cloud.google.com/apigee/docs/api-platform/cache/property-sets)
* [JavaScript](https://cloud.google.com/apigee/docs/api-platform/reference/policies/javascript-policy?hl=en) policy to set HTTP response headers with values
retrieved from the same property set

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `property-set` directory in the Cloud shell.

```sh
cd property-set
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="property-set/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources necessary to test the Property Set.

```sh
./deploy.sh
```

This script creates a sample API Proxy. The script also tests that the deployment and configuration has been successful.

### Test the APIs

The script that deploys the Apigee API proxies prints the proxy and other information you will need to run the commands below.

Run the following curl command:

```sh
curl -v https://$APIGEE_HOST/v1/samples/property-set
```

Use the debug tool inside Apigee to see how we access values in a property set, using the following syntax:

```propertyset.<property_set_name>.<property_name>```

### AssignMessage policy to access a Property Set

You can use the ```AssignMessage``` policy to assign the value of property set key to a flow variable dynamically.
In this sample, we create a JSON response, which contains values of the property set for two keys.

Here is the configuration of the ```AssignMessage``` policy:

```xml
<AssignMessage name="AM-SetResponseUsingPropertySet">
  <Set>
    <Payload contentType="application/json">
    {
      "foo":"{propertyset.myProps.foo}",
      "message":"{propertyset.myProps.message}"
    }
    </Payload>
  </Set>
  <IgnoreUnresolvedVariables>true</IgnoreUnresolvedVariables>
  <AssignTo createNew="false" transport="http" type="response"/>
</AssignMessage>
```

...and the JSON payload (response) that is created:

```json
{
  "foo": "bar",
  "message": "This is a basic message."
}
```

Note: private information should be handled using encrypted 
KVMs (Key Value Maps) and not property sets.

### JavaScript policy to access a Property Set

Access property set values anywhere in an API proxy where you can access flow variables:
in policies, flows, JavaScript code, and so on.

For example, in a JavaScript policy, use the ```getVariable()``` method
to get a value from a property set:

```javascript
...
// access properties of the myProps.properties file
var baz = context.getVariable('propertyset.myProps.baz');
var note = context.getVariable('propertyset.myProps.note_message');
...
```

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented a proxy that uses a Property Set and an AssignMessage
policy to get data from it using context variables.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```
