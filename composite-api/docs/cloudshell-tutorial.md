# Composite API

---
This sample shows how to implement a composite API (e.g. mashup) using Apigee's [ServiceCallout Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/service-callout-policy) and [ExtractVariables Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/extract-variables-policy)

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `composite-api` directory in the Cloud shell.

```sh
cd composite-api
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="composite-api/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources necessary to create a composite API.

```sh
./deploy-composite-api.sh
```

This script creates a sample API Proxy that invokes 2 different APIs over the internet. The script also tests that the deployment and configuration has been successful.

### Test the API

The script that deploys the Apigee API proxies prints the proxy information you will need to run the commands below.

Run the following command to test the composite API:

```sh
curl https://$APIGEE_HOST/v1/samples/composite-api/temperature?near=Chicago
```

Observe how the API Proxy returns a 200 OK along with a JSON response which contains the current temperature in Chicago. There are two steps to this API Proxy which you can see if you step through the Apigee Debug tool. The first step of the API Proxy is to make an API call to a geocoding API to convert "Chicago" into its latitude and longitude. The second step of the API Proxy is to call the API target which is a weather API that returns the current temperature of a given latitude and longitude (which was retrieved in the first API call). Try this same API call with different cities, and use the Apigee Debug Tool to see what happens.

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented a composite API in Apigee.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-composite-api.sh
```
