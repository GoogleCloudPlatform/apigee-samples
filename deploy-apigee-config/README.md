# Deploy Apigee environment and org configurations using Apigee Maven plugin and Cloud Build

This sample demonstrates how to use the [Apigee Maven config plugin](https://github.com/apigee/apigee-config-maven-plugin) to push environment configurations like Targetservers, KeyValueMaps and Organization configurations like API Products, Developers and Developer Apps to Apigee using [Cloud Build](https://cloud.google.com/build/docs/overview)

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Access to push configurations to Apigee (API Admin or Org Admin role), trigger Cloud Build
3. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these pre-configured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * Maven 3.x

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=deploy-apigee-config/docs/cloudshell-tutorial-maven.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the deploy-apigee-config directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd deploy-apigee-config
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

To verify if the configurations were created, login to the [Apigee console](https://apigee.google.com).
- Navigate to "Admin" --> "Environments" --> "Target Servers", you should see a target server `SampleTarget` created.
- Similarly navigate to "Admin" --> "Environments" --> "Key Value Maps", you should see a Key Value Map `SampleKVM` created
- Navigate to "Publish" --> "API Products", you should find the `sample-product` product created.
- Navigate to "Publish" --> "Developers", you should find the `Sample Developer` developer created.
- Navigate to "Publish" --> "Apps", you should find the `sampleapp` app created.

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-deploy-apigee-sharedflow.sh
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