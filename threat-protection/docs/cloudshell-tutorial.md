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

### Test the APIs

The script that deploys the Apigee API proxies prints the proxy and app information you will need to run the commands below.

Set the proxy URL:

```sh
export PROXY_URL=<replace with script output>
```

Run the following command to test the Regular Expression Policy:

```sh
curl https://$APIGEE_HOST/v1/threat-protection?query=delete
```

Observe how the API Proxy returns an error because it found a suspicious `delete` statement in the query string (e.g. a potential SQL injection attack).

Next, repeat the command with a `select` string:

```sh
curl https://$APIGEE_HOST/v1/threat-protection?query=select
```

Observe how the API Proxy returns a 200 OK as the Regular Expression Policy did not find a potential threat in the HTTP request.

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
