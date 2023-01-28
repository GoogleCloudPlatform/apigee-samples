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
cd integrated-developer-portal
```

2. Edit the `env.sh` and configure the ENV vars

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy the Apigee resources necessary to create an integrated developer portal

```bash
./deploy-integrated-developer-portal.sh
```

This script creates an API Proxy, API product, a sample App developer, and App. The script also tests that the deployment and configuration has been sucessfull. It does not, however, create the developer portal. We will create and test that manually.

## Testing the Client Credentials Proxy
To run the tests manually, first retrieve Node.js dependencies with:
```
npm install
```
and then:
```
npm run test
```

## Manually call the API

The script that deploys the Apigee API proxies prints the proxy and app information you will need to run the commands below.

```
curl -v http://$APIGEE_HOST/v1/sample/integrated-developer-portal -d "apikey=$APP_CLIENT_ID"
```
> _Note: Under normal circumstances, avoid providing secrets on the command itself using `-u`_

---
## Create Integrated Developer Portal

You've successfully created an api secured proxy and all the resources needed to access it. Now we need to create the integrated developer portal:

1. Access the portals page from the Apigee homepage. Publish > Portals
2. Click the +Portal button
3. For name you can use "Sample Integrated Developer Portal". You can leave Description blank.

We also need to add our API product to the portal:

1. Access your new Sample Integrated Developer Portal
2. Enter the APIs tab, if not already selected
3. Click + to add a new API product to the catalog
4. Select the sample-integrated-developer-portal-product product and click next
5. Configure as shown below
- Display title: Sample Integrated Developer Portal
- Display description: A portal for an API key protected proxy
- Published: Select published (checked)
- Require developers to specify a callback URL: Keep deselected (unchecked)
- Visibility: Public (visibile to anyone)
- API product image: Image of your choice
- API documentation: Use the [integrated-developer-portal.yaml](integrated-developer-portal.yaml) OpenAPI file from this repo:
    - Download [integrated-developer-portal.yaml](integrated-developer-portal.yaml) to your local computer
    - Make note of your Apigee domain from the Apigee dashboard at Admin > Environments > Groups
    - Replace "\[YOUR_DOMAIN\]" with your Apigee domain
    - Upload your updated integrated-developer-portal.yaml as API documentation
6. Click save

## Test Integrated Developer Portal

Now that we have a developer portal, let's walk through it's workflow. First we'll create our create our developer account and sign in, then we'll create a Apigee app complete with a client id and secret, then we'll use the client id to authorize our requests and test our API. To do so, follow the steps below: 

1. 
2. 
3. 

## Cleanup

After you create your integrated developer portal you can clean up the artefacts from this sample in your Apigee Organization. First source your `env.sh` script, and then run

```bash
./clean-up-oauth-client-credentials.sh
```

After this, you need to manually delete the Apigee portal. Navigate to Publish > Portals, find you portal in the portal table, hover over it, and select the trash can icon to permanently delete your integrated developer portal.

## Not Google Product Clause

This is not an officially supported Google product, nor is it part of an
official Google product.

## Support

If you need support or assistance, you can try inquiring on [Google Cloud Community
forum dedicated to Apigee](https://www.googlecloudcommunity.com/gc/Apigee/bd-p/cloud-apigee).

## License

This material is [Copyright 2023 Google LLC](./NOTICE)
and is licensed under the [Apache 2.0 License](LICENSE).