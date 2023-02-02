# Integrated Developer Portal

This sample lets you create an integrated developer portal for your API product

## About integrated developer portals

Apigee's integrated developer portal enables users to quickly and easily stand up a developer portal for their APIs. These portals are fully supported by Google and offer premium capabilities for the majority of developer portal needs. To learn more, see the [official documentation](https://cloud.google.com/apigee/docs/api-platform/publish/portal/build-integrated-portal).

## How it works


## Implementation on Apigee 

The Apigee proxy sample uses only a few policies:
1. An API Key policy to verify incoming request API Key credentials
2. A CORS policy to allow requests from the developer portal webpage

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm

# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions in Cloud Shell. Alternatively, follow the instructions below.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=integrated-developer-portal/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the integrated-developer-portal directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/integrated-developer-portal
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

4. Deploy the Apigee resources necessary to create an integrated developer portal

```bash
./deploy-integrated-developer-portal.sh
```

This script creates an API Proxy and API product. It does not, however, create the developer portal. We will create and test that manually.

---
## Create Integrated Developer Portal

You've successfully created a secured Apigee proxy. Now we need to create the integrated developer portal:

1. Access the portals page from the [Apigee homepage](https://apigee.google.com). Publish > Portals
2. Click the +Portal button
3. For name you can use "Sample Integrated Developer Portal". You can leave Description blank.

We also need to add our API product to the portal:

1. Access your new Sample Integrated Developer Portal
2. Enter the API catalog tab, if not already selected
3. Click + to add a new API product to the catalog
4. Select the sample-integrated-developer-portal-product product and click next
5. Configure as shown below
- Published: Select published (checked)
- Display title: Leave default name, sample-integrated-developer-portal-product
- Display description: A portal for an API key protected proxy
- Require developers to specify a callback URL: Keep deselected (unchecked)
- Audience: Anonymous users (anyone can view)
- API product image: Image of your choice
- API documentation: Use the [integrated-developer-portal.yaml](integrated-developer-portal.yaml) OpenAPI document from this repo:
    - Download [integrated-developer-portal.yaml](integrated-developer-portal.yaml) to your local computer
    - Make note of your Apigee domain from the Apigee dashboard at Admin > Environments > Groups
    - Replace "\[YOUR_DOMAIN\]" with your Apigee domain
    - Upload your updated integrated-developer-portal.yaml as API documentation
6. Scroll up and click save

## Test Integrated Developer Portal

Now that we have a developer portal, let's walk through its workflow. First we'll create our create our developer account and sign in, then we'll make an Apigee app complete with a client id and secret, and finally we'll use the client id to authorize our requests and test our API. To do so, follow the steps below: 

1. Navigate to your newly created portal. Portals > Sample Integrated Developer Portal
2. Enter the portal by clicking the Live Portal button at the top right, or with the following URL: https://\[APIGEE-ORG\]-sampleintegrateddeveloperportal.apigee.io
3. Click the Sign In button and create an account. You need to enter a valid email as the portal necessitate an email confirmation. Note: this creates an Apigee developer account
4. Navigate back to your portal's homepage (https://\[APIGEE-ORG\]-sampleintegrateddeveloperportal.apigee.io) and make sure that you're signed in
5. Open the dropdown menu by clicking on your account and select Apps
6. Select +NEW APP and update the following fields. Note: this creates an Apigee App for your developer
- App Name: Sample App
- APIs: Enable sample-integrated-developer-portal-product
7. Click the SAVE button
8. Click into APIs from the top navbar
9. Click into your sample-integrated-developer-portal-product
10. Select AUTHORIZE and select your app from the dropdown. This authorizes all of your portal requests with your App's API key
11. Select the / GET request Path
12. Under Try this API, click the EXECUTE button
13. You should receive a 200 OK response from Apigee. The body of the response is a copy of the request data you sent to Apigee

## Cleanup

After you create your integrated developer portal you can clean up the artifacts from this sample in your Apigee Organization. First source your `env.sh` script, and then run

```bash
./clean-up-integrated-developer-portal.sh
```

After this, you need to manually delete the created Apigee resources:
1. Navigate to Publish > Developers
2. Find the account you created in your developer portal, hover over it, and select the trash can icon to delete
3. Navigate to Publish > API Products
4. Find the product you created, open the actions menu, and delete it
5. Navigate to Publish > Portals
6. Find your Sample Integrated Developer Portal, hover over it, and select the trash can icon to delete
