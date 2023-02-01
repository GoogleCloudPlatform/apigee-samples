# Use Cloud Run Service from Apigee Proxy using Apigee Maven plugin and Cloud Build

This sample demonstrates how to use Cloud Run Service from Apigee Proxy using Cloud Build.

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Access to deploy proxies to Apigee, trigger Cloud Build
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

1. Clone the apigee-samples repo, and switch the deploy-apigee-proxy directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd cloud-run
```

2. Edit the `env.sh` and configure the ENV vars

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Enable the Cloud Build API and assign Apigee Org admin role to the Cloud Build service account

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com

gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/apigee.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/iam.serviceAccountUser"
```

4. Trigger the build

```bash
gcloud builds submit --config cloudbuild.yaml . \
    --substitutions="_SERVICE=$CLOUD_RUN_SERVICE","_REGION=$CLOUD_RUN_REGION","_APIGEE_TEST_ENV=test"
```

## Test the APIs

You can test the API call to make sure the deployment was successful

```bash
curl -v -X GET https://$APIGEE_HOST/v1/samples/cloud-run-sample"
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-cloud-run.sh
```

## Not Google Product Clause

This is not an officially supported Google product, nor is it part of an
official Google product.

## Support

If you need support or assistance, you can try inquiring on [Google Cloud Community
forum dedicated to Apigee](https://www.googlecloudcommunity.com/gc/Apigee/bd-p/cloud-apigee).

## License

This material is [Copyright 2023 Google LLC](./NOTICE)
and is licensed under the [Apache 2.0 License](LICENSE).
