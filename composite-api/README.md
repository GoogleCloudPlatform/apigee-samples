# Composite API

---
This sample shows how to implement composite APIs (e.g. mashup) using Apigee's [ServiceCallout Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/service-callout-policy) and [ExtractVariables Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/extract-variables-policy)

Let's get started!

---

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

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=composite-api/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the `apigee-samples` repo, and switch to the `composite-api` directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/composite-api
```

2. Edit `env.sh` and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee API proxies

```bash
./deploy-composite-api.sh
```

## Testing the Proxy

To run the tests, first retrieve Node.js dependencies with:

```bash
npm install
```

and then run the tests:

```bash
npm run test
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-composite-api.sh
```
