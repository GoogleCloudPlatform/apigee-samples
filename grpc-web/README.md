# gRPC-Web on Apigee

This sample demonstrates how Apigee can secure your [gRPC-Web](https://github.com/grpc/grpc-web) backends. By utilizing Apigee's Threat Protection policies, this example specifically showcases how to detect and block HTML tags in payloads, returning a 400 error code to prevent potential malicious input.

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
    * protoc
    * xxd

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

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=grpc-web/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the `apigee-samples` repo, and switch the `grpc-web` directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/grpc-web
```

2. Edit the `env.sh` file and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `REGION` the region where Cloud Run will be deployed
* `APIGEE_ENV` the region where your Apigee instance is provisioned
* `APIGEE_HOST` the hostname configured in the Apigee Environment Group

Now source the `env.sh` file

```bash
source ./env.sh
```

Let's first deploy the gRPC-Web application to Cloud Run

```bash
cd app
./deploy-grpc-web-cloud-run.sh
cd ../
```

**NOTE:** This may take a few minutes to complete.

Once the script is complete, export the BACKEND_SERVICE variable.

Now that the Cloud Run service is deployed, let's build the Apigee proxy

```sh
./deploy.sh
```

This will compile and build the Java [callout](../grpc-web/callout) to create a jar file which gets copied over to the proxy resources. The proxy will then be deployed to Apigee.

Execute the cURL commands as prompted by the script

First command should return a 200 response as its not a threat request.

However the second command should return a 400 response as it is a threat request.

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```
