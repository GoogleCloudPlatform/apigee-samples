# Publish OpenAPI Spec to Apigee Integrated portal using Apigee Maven plugin and Cloud Build

This sample demonstrates how to use the [Apigee Maven config plugin](https://github.com/apigee/apigee-config-maven-plugin) to publish configurations like API Docs and API Categories to Apigee Integrated Portal using [Cloud Build](https://cloud.google.com/build/docs/overview)

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Create a [Developer portal](https://cloud.google.com/apigee/docs/api-platform/publish/portal/build-integrated-portal)
3. Access to push configurations to Apigee (API Admin or Org Admin role), trigger Cloud Build
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these pre-configured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * Maven 3.x

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=publish-to-apigee-portal/docs/cloudshell-tutorial-maven.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the publish-to-apigee-portal directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/publish-to-apigee-portal
```

2. Edit the `env.sh` and configure the ENV vars

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV.
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `APIGEE_PORTAL_SITE_ID` the name of the portal, in the form ORG_NAME-PORTAL_NAME,
    where ORG_NAME is the name of the organization
    PORTAL_NAME is the portal name converted to all lowercase
    and with spaces and dashes removed. For example, my-org-myportal.

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
    --substitutions="_APIGEE_HOST=$APIGEE_HOST,_APIGEE_TEST_ENV=$APIGEE_ENV,_APIGEE_PORTAL_SITE_ID=$APIGEE_PORTAL_SITE_ID"
```

## Verification

To verify if the configurations were created, open your Integrated portal in a browser

* Click the "API" from the menu header, you should see `MockTarget` API created.
* Click `MockTarget` to see the different paths of the API
* Click the `/echo` path from the left menu and under the `Try this API` section, click the "EXECUTE" button to see the response from Apigee
* You can enable DEBUG in Apigee and make the calls from the portal to see the transaction in DEBUG

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./cleanup.sh
```
