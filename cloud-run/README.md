# Use Cloud Run Service from Apigee Proxy using Apigee Maven plugin and Cloud Build

This sample demonstrates how to use Cloud Run Service from Apigee Proxy using Cloud Build.

### Screencast

[![Alt text](https://img.youtube.com/vi/oyFyPs0tg8Y/0.jpg)](https://www.youtube.com/watch?v=oyFyPs0tg8Y)

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Access to deploy proxies to Apigee, deploy Cloud Run and trigger Cloud Build
3. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these pre-configured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=cloud-run/docs/cloudshell-tutorial-maven.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the cloud-run directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/cloud-run
```

2. Edit the `env.sh` and configure the ENV vars

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `CLOUD_RUN_REGION` the region to deploy cloud run service.

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Enable the IAM API, Cloud Build API, Cloud Run API and Container Registry API. Assign Apigee Org admin, Cloud Run Admin , Service Account User and Admin role to the Cloud Build service account

```bash
gcloud services enable iam.googleapis.com cloudbuild.googleapis.com run.googleapis.com containerregistry.googleapis.com

gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/apigee.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/iam.serviceAccountAdmin"
```

4. Create Service Account with Cloud Run Invoker role

To invoke cloud run from Apigee Proxy requires a service account with run.invoker permission. This step is optional if you are using cloudbuild to trigger build as mentioned below.

```bash
gcloud iam service-accounts create run-mock-target-sa \
          --project "$PROJECT_ID" || true

gcloud run services add-iam-policy-binding ${_SERVICE} \
          --region ${_REGION} \
          --member serviceAccount:run-mock-target-sa@"$PROJECT_ID".iam.gserviceaccount.com \
          --role roles/run.invoker \
          --platform managed

```

5. Trigger the build

```bash
gcloud builds submit --config cloudbuild.yaml . \
    --substitutions="_SERVICE=$CLOUD_RUN_SERVICE","_REGION=$CLOUD_RUN_REGION","_APIGEE_TEST_ENV=$APIGEE_ENV"
```

## Test the APIs

You can test the API call to make sure the deployment was successful

```bash
curl -v -X GET https://$APIGEE_HOST/v1/samples/cloud-run-sample
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-cloud-run.sh
```
