# Apigee Java Callout Tutorial

---
This sample helps you configure an Apigee Proxy with a Java Callout Policy

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'java-callout' directory in the Cloud shell.

```sh
cd java-callout
```

Edit the provided sample `env.sh` file, and set the environment variables there.

   * `PROJECT` the project where your Apigee organization is located
   * `APIGEE_ENV` the Apigee environment where the demo resources should be created
   * `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV

Click <walkthrough-editor-open-file filePath="java-callout/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

## Deploy Apigee components

Next, let's create and deploy the Apigee proxy.

```sh
./deploy-java-callout.sh
```

## Test the APIs

Generate a few sample requests to the deployed API Proxy.

```sh
curl  https://$APIGEE_HOST/v1/samples/java-callout
```

> _If you want, consider also checking the call in the [Debug](https://cloud.google.com/apigee/docs/api-platform/debug/trace) view_

**Successful deployment of the proxy will return a “Hello, World!” response.**

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully made an Apigee Proxy that implements custom Java code using a Java Callout!

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-java-callout.sh
```
