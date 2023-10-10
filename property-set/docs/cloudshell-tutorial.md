# Property Set

---
This sample shows how to easily get data from a Property Set using an AssignMessage policy.

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

You can use the AssignMessage policy to assign the value of property set key to a flow variable dynamically.
In this sample, we create a JSON response, which contains values of the property set for each key:

```
{
  "foo": "bar",
  "baz": "biff",
  "message": "This is a basic message.",
  "note_message": "This is an important message.",
  "error_message": "This is an error message.",
  "publickey": "abc123",
  "privatekey": "splitwithsoundman"
}
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
