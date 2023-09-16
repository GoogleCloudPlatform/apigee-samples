# Basic Caching

---
This sample shows how to implement caching using Apigee's [ResponseCache](https://cloud.google.com/apigee/docs/api-platform/reference/policies/response-cache-policy), [PopulateCache](https://cloud.google.com/apigee/docs/api-platform/reference/policies/populate-cache-policy), and [LookupCache](https://cloud.google.com/apigee/docs/api-platform/reference/policies/lookup-cache-policy) policies.

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `basic-caching` directory in the Cloud shell.

```sh
cd basic-caching
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="basic-caching/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources necessary to test the caching policies.

```sh
./deploy-basic-caching.sh
```

This will not only deploy the proxy but also run the tests.

### Test the APIs

The script that deploys the Apigee API proxies prints the proxy and app information you will need to run the commands below.

Run the following command make the request:

```sh
curl -w "%{time_total}\n" -so /dev/null "https://$APIGEE_HOST/v1/samples/basic-caching?q=google%20cloud&country=us"
```

Observe the response time output to the console. Run the following command to make another request:

```sh
curl -w "%{time_total}\n" -so /dev/null "https://$APIGEE_HOST/v1/samples/basic-caching?q=google%20cloud&country=us"
```

Observe that this time, the response time is lower than that of the previous request.

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented caching in your API!

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, ensure the `PROJECT`, `APIGEE_HOST`, and `APIGEE_ENV` environment variables have been set as described in Setup environment, and then run the following command.

```bash
./clean-up-basic-caching.sh
```
