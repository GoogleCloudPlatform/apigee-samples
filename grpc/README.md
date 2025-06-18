# gRPC on Apigee

This sample shows how to use Apigee in front of your gRPC backends.
For this example we will be using Cloud Run to host a gRPC server and configure it as a target server in Apigee. Apigee will act as a simple reverse proxy in front of the gRPC backend. For more detailed information on using gRPC proxies in Apigee, please refer to the official [documentation](https://cloud.google.com/apigee/docs/api-platform/fundamentals/build-simple-api-proxy#creating-grpc-api-proxies).

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Access to deploy proxies, create products, apps and developers in Apigee
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm
    * docker

5. The following GCP APIs will be enabled:
    * Cloud Run API
    * Container Registry API
    * Compute Engine API

6. Make sure that you have ONE the following permissions:
    * Owner role
    * Editor role

    The following set of roles:

    * [Cloud Build Editor](https://cloud.google.com/build/docs/iam-roles-permissions) role
    * [Artifact Registry Admin](https://cloud.google.com/iam/docs/understanding-roles#artifactregistry.repoAdmin) role
    * [Storage Admin](https://cloud.google.com/storage/docs/access-control/iam-roles) role
    * [Cloud Run Admin](https://cloud.google.com/build/docs/deploying-builds/deploy-cloud-run#fully-managed) role
    * Service Account User role

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=grpc/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the `apigee-samples` repo, and switch the `grpc` directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/grpc
```

2. Edit the `env.sh` file and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `NETWORK` the VPC network where the PSC NEG will be deployed
* `SUBNET` the VPC subnet where the PSC NEG will be deployed

Now source the `env.sh` file

```bash
source ./env.sh
```

Let's run the script that will create and deploy the resources necessary to test the gRPC functionality. This script will create the following:

* An External Loadbalancer with an HTTP2 backend
* Deploy a sample gRPC Greeter service to Cloud Run
* Deploy an API proxy, target server, developer, app and api product

 Finally it tests that the deployment and configuration has been successful.

3. Run the deploy.sh script:

```sh
./deploy.sh
```

## Manually Testing the gRPC Proxy

To manually test the proxy, make requests using grpcurl or another gRPC client:

```sh
grpcurl -H "x-apikey:$CLIENT_ID" -import-path $PWD/grpc-backend/examples/protos -proto helloworld.proto -d '{"name\":"Guest"}' <YOUR_APIGEE_GRPC_HOSTNAME>:443 helloworld.Greeter/SayHello"
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```
