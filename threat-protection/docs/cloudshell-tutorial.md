# Threat Protection

---
This sample shows how to implement threat protection using Apigee's [RegularExpression Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/regular-expression-protection) policy and [JSONThreatProtection Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/json-threat-protection-policy) policy

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `threat-protection` directory in the Cloud shell.

```sh
cd threat-protection
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="threat-protection/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources necessary to test threat protection.

```sh
./deploy-threat-protection.sh
```

This script creates a sample API Proxy that demonstrates two threat protection examples. The script also tests that the deployment and configuration has been successful.

### Test the API

The script that deploys the Apigee API proxies prints the proxy and app information you will need to run the commands below.

Run the following command to test the Regular Expression Policy:

```sh
curl https://$APIGEE_HOST/v1/samples/threat-protection/json?query=delete
```

Observe how the API Proxy returns an error because it found a suspicious `delete` statement in the query string (e.g. a potential SQL injection attack).

Next, repeat the command with `select` in the query string:

```sh
curl https://$APIGEE_HOST/v1/samples/threat-protection/json?query=select
```

Observe how the API Proxy returns a 200 OK as the Regular Expression Policy did not find a potential threat in the HTTP request.

Run the following command to test the JSON Threat Protection Policy:

```sh
curl -X POST https://$APIGEE_HOST/v1/samples/threat-protection/echo -H 'Content-Type: application/json' -d '{"field1": "test_value1", "field2": "test_value2", "field3]": "test_value3", "field4": "test_value4", "field5": "test_value5", "field6": "test_value6"}'
```

Observe how the API Proxy returns an error because the JSON request has more fields than what was expected by the JSON Threat Protection Policy.  See the JSON Threat Protection policy in Apigee to see the configuration.  You can set the JSON Threat Protection Policy to conform to the valid JSON payloads you expect in the HTTP request body.

Next, run the following curl request:

```sh
curl -X POST https://$APIGEE_HOST/v1/samples/threat-protection/echo -H 'Content-Type: application/json' -d '{"field1": "test_value1", "field2": "test_value2", "field3]": "test_value3", "field4": "test_value4", "field5": "test_value5"}'
```

Observe how the API Proxy returns a 200 OK along with the output as the JSON Threat Protection Policy confirmed the input payload was as expected (i.e. correct number of input fields).

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented threat protection in Apigee.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-threat-protection.sh
```
