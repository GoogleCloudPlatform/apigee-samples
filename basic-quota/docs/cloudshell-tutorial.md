# Basic Quota

---
This sample shows how to implement a dynamic API consumption limit using Apigee's [Quota](https://cloud.google.com/apigee/docs/api-platform/reference/policies/quota-policy) policy. 

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `basic-quota` directory in the Cloud shell.

```sh
cd basic-quota
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="basic-quota/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources necessary to test the quota policy.

```sh
./deploy-basic-quota.sh
```

This script creates a sample API Proxy, a Developer, two API products, and two Apps. The script also tests that the deployment and configuration has been sucessful.


### Test the APIs

The script that deploys the Apigee API proxies prints the proxy and app information you will need to run the commands below.

Set the proxy URL:
```sh
export PROXY_URL=<replace with script output>
```

Set the trial app key:
```sh
export CLIENT_ID_1=<replace with script output>
```

Set the premium app key:
```sh
export CLIENT_ID_2=<replace with script output>
```

Run the following command several times in succession:
```sh
curl https://$APIGEE_HOST/v1/samples/basic-quota?apikey=$CLIENT_ID_1
```

Observe how the `available` and `used` values in the response payload update on each request made. On the eleventh request, observe the [429](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/429) status code and payload indicating the quota has been exceeded. Wait up to a minute and repeat the command again. Observe how the counter has reset and requests begin to succeed again.

Next, repeat the command using the second application key:
```sh
curl https://$APIGEE_HOST/v1/samples/basic-quota?apikey=$CLIENT_ID_2
```

Observe the new, larger value in the `allowed` field contained in the response payload. The `allowed` value is applied dynamically based on the API product configuration.

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented a dynamic API consumption quota limit.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artefacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-basic-quota.sh
```
