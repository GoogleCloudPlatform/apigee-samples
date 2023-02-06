# Deploy Apigee Sharedflow using Apigee Maven plugin and Cloud Build

This sample demonstrates how to use the [Apigee Maven deploy plugin](https://github.com/apigee/apigee-deploy-maven-plugin) to deploy a sharedflow to Apigee using [Cloud Build](https://cloud.google.com/build/docs/overview)

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Access to deploy sharedflow to Apigee, trigger Cloud Build
3. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these pre-configured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=deploy-apigee-sharedflow/docs/cloudshell-tutorial-maven.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the deploy-apigee-sharedflow directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/deploy-apigee-sharedflow
```

2. Edit the `env.sh` and configure the ENV vars

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Enable the Cloud Build API and assign Apigee Org admin role to the Cloud Build service account

```bash
gcloud services enable cloudbuild.googleapis.com

gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/apigee.admin"
```

4. Trigger the build

```bash
gcloud builds submit --config cloudbuild.yaml . \
    --substitutions="_APIGEE_TEST_ENV=$APIGEE_ENV"
```

## Verification

Login to the [Apigee console](https://apigee.google.com), click "Develop" and then "Shared Flows", you should see a sharedflow called `sample-hello-ci-cd-sf` imported and deployed.

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-deploy-apigee-sharedflow.sh
```
