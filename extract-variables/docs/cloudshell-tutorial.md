# Extract Variables and Assign Message

---
This sample shows how to easily extract fields from an XML and JSON response.


Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `extract-variables` directory in the Cloud shell.

```sh
cd extract-variables
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="extract-variables/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources necessary to test the ExtractVariables and AssignMessage policy.

```sh
./deploy.sh
```

This script creates a sample API Proxy. The script also tests that the deployment and configuration has been successful.


### Test the APIs

The script that deploys the Apigee API proxies prints the proxy and other information you will need to run the commands below.

Run the following curl command:
```sh
curl https://$APIGEE_HOST/v1/samples/extract-variables
```

Use the debug tool inside Apigee to see how we:

1. Extract fields and store them into variables from the XML response received from the target. Use  the XPath syntax to identify the data to extract.
2. Convert the response payload from XML to JSON.
3. Extract more variables from the converted JSON payload. Use the JSONPath syntax to identify the data to extract.
4. Assign the extracted variables to the HTTP response headers.

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented a proxy that extracts variables from XML and JSON and assigns custom headers.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```
