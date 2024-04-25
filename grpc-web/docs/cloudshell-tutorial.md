# gRPC-Web in Apigee

---
This sample demonstrates how Apigee can secure your [gRPC-Web](https://github.com/grpc/grpc-web) backends. By utilizing Apigee's Threat Protection policies, this example specifically showcases how to detect and block HTML tags in payloads, returning a 400 error code to prevent potential malicious input.

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell and that you are in the right GCP project to deploy the gRPC service in Cloud Run.

```sh
gcloud auth login
```

```sh
gcloud config list
```

Change the directory to the grpc-web sample:

```sh
cd grpc-web
```

---

## Configure the environment

1. Click <walkthrough-editor-open-file filePath="grpc-web/env.sh">here</walkthrough-editor-open-file> to open the `env.sh` file and set the following environment variables:

* `PROJECT` the project where your Apigee organization is located
* `REGION` the region where Cloud Run will be deployed
* `APIGEE_ENV` the region where your Apigee instance is provisioned
* `APIGEE_HOST` the hostname configured in the Apigee Environment Group

2. Now source the `env.sh` file

```bash
source ./env.sh
```

---

## Deploy the gRPC-Web service

Let's first deploy the gRPC-Web application to Cloud Run

```bash
cd app
./deploy-grpc-web-cloud-run.sh
cd ../
```

**NOTE:** This may take a few minutes to complete.

Once the script is complete, export the BACKEND_SERVICE variable.

---

## Deploy the Apigee proxy

Now that the Cloud Run service is deployed, let's build the Apigee proxy

```sh
./deploy.sh
```

This will compile and build the Java [callout](../callout) to create a jar file which gets copied over to the proxy resources. The proxy will then be deployed to Apigee.

Execute the cURL commands as prompted by the script:

First command should return a 200 response as its not a threat request.

However the second command should return a 400 response as it is a threat request.

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented a proxy that points to the gRPC-Web service and checks for any attacks.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this sample in your GCP environment, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```
