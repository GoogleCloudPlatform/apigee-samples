# gRPC in Apigee

---
This sample shows how to use Apigee in front of your gRPC backends:


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

Change the directory to the grpc sample:

```sh
cd grpc
```

---

## Deploy Apigee and GCP components

1. Click <walkthrough-editor-open-file filePath="grpc/env.sh">here</walkthrough-editor-open-file> to open the `env.sh` fileand set the following environment variables:

* `PROJECT` the project where your Apigee organization is located
* `NETWORK` the VPC network where the PSC NEG will be deployed
* `SUBNET` the VPC subnet where the PSC NEG will be deployed


2. Now source the `env.sh` file

```bash
source ./env.sh
```

Let's run the script that will create and deploy the resources necessary to test the gRPC functionality. This script will create the following:

* An External Loadbalancer with an HTTP2 backend
* Deploy a sample gRPC Greeter service to Cloud Run
* Deploy an API proxy, target server, developer, app and api product 


```sh
./deploy.sh
```

## Manually Testing the gRPC Proxy

## Example Requests
To manually test the proxy, make requests using grpcurl or another gRPC client:

```sh
grpcurl -H \"x-apikey:$CLIENT_ID\" -import-path $PWD/grpc-backend/examples/protos -proto helloworld.proto -d '{\"name\":\"Guest\"}' <YOUR_APIGEE_GRPC_HOSTNAME>:443 helloworld.Greeter/SayHello"
```


---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented a proxy that supports gRPC with a target gRPC server running in Cloud Run!

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this sample in your GCP environment, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```
