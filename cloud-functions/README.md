# Connect to Cloud Function from an Apigee Proxy

This sample demonstrates how to connect to a Cloud Function (gen2) from an Apigee API Proxy.

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)

2. Access to import and deploy proxies to Apigee, and deploy Cloud Functions

3. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance

4. Make sure the following tools are available in your terminal's PATH
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm

   Cloud Shell has all of these pre-configured.

## Tutorial

Click the link to follow a tutorial that runs right within GCP
CloudShell. Follow the instructions as shown on the right hand side of your
browser window.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=cloud-functions/docs/cloudshell-tutorial.md)

## Cleanup

If you want to clean up the artifacts from this example in your Apigee
organization, first source your `env.sh` script, and then run

```bash
./clean-up-cloud-run.sh
```
