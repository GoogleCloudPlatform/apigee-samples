# Integrated Developer Portal

This sample lets you create a Drupal developer portal for your Apigee API product

## About integrated developer portals

Apigee's Drupal developer portal enables users to quickly and easily stand up a highly customizable developer portal for their APIs. Unlike the integrated developer portal, the Drupal portal isn't managed by Apigee. So we will use the Google Cloud Platform (GCP) Marketplace solution to deploy the portal's infrastructure. To learn more about Apigee Drupal portals, see the [Google documentation](https://cloud.google.com/apigee/docs/api-platform/publish/drupal/open-source-drupal).

## Implementation on Apigee 

The Apigee proxy sample uses only a few policies:
1. An API Key policy to verify incoming request API Key credentials
2. A CORS policy to allow requests from the developer portal webpage

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Have access to deploy proxies, create products, and provision a portal in Apigee
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm
5. You have deployed the Drupal developer portal as described in the [documentation](https://cloud.google.com/apigee/docs/api-platform/publish/drupal/get-started-cloud-marketplace). No customization to the portal is needed as a prerequisite.

# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions in Cloud Shell. Alternatively, follow the instructions below.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=integrated-developer-portal/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch to the integrated-developer-portal directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apige-samples/integrated-developer-portal
```

2. Edit the `env.sh` and configure the ENV vars

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

## Deploy Apigee components

Next, let's deploy some Apigee resources necessary to create an integrated developer portal

```bash
./deploy-integrated-developer-portal.sh
```

**NOTE: This script creates an API Proxy and API product. It does not, however, create the developer portal. We will create and test that manually**

## Test Integrated Developer Portal

## Conclusion & Cleanup

To clean up the artifacts created:

First, you need to manually delete the Drupal developer portal


After that, source your `env.sh` script and run the following to delete your product and proxy:

```bash
./clean-up-integrated-developer-portal.sh
```
