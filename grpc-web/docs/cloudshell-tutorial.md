# gRPC-Web in Apigee

---
This sample shows how to use Apigee in front of your gRPC backends using [gRPC-Web](https://github.com/grpc/grpc-web). In this example, we will show how Apigee can secure your grpc workload using the Threat Protection policies that are available. This sample basically checks for HTML tags in the payload and returns a 400 error code

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

**NOTE** This may take a few minutes to complete.

Once the script is complete, export the BACKEND_SERVICE variable.

---

## Deploy the Apigee proxy

Now that the Cloud Run service is deployed, let's build the Apigee proxy

```sh
./deploy.sh
```

This will compile and build the Java [callout](../callout) to create a jar file which gets copied over to the proxy resources. The proxy will then be deployed to Apigee.

Execute the cURL commands as prompted by the script:

```sh
curl -i https://$APIGEE_HOST/v1/samples/grpc-web/helloworld.Greeter/SayHello \
    -H 'content-type: application/grpc-web-text' \
    --data-raw 'AAAAAAYKBGhvbWU='
```

and

```sh
curl -i https://$APIGEE_HOST/v1/samples/grpc-web/helloworld.Greeter/SayHello \
    -H 'content-type: application/grpc-web-text' \
    --data-raw 'AAAAAEkKRzxsaXN0aW5nIG9ucG9pbnRlcnJhd3VwZGF0ZT1wcm9tcHQoMSkgc3R5bGU9ZGlzcGxheTpibG9jaz5YU1M8L2xpc3Rpbmc+'
```

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
