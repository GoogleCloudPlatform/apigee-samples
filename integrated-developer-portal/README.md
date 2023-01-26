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

Use the following GCP CloudShell tutorial, and follow the instructions.

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

3. Deploy Apigee API proxies, products and apps

```bash
./deploy-integrated-developer-portal.sh
```

## Testing the Client Credentials Proxy
To run the tests, first retrieve Node.js dependencies with:
```
npm install
```
and then:
```
npm run test
```

## Example Requests
For additional examples, including negative test cases, see 

## Test Developer Portal

## Cleanup

## Not Google Product Clause

This is not an officially supported Google product, nor is it part of an
official Google product.

## Support

If you need support or assistance, you can try inquiring on [Google Cloud Community
forum dedicated to Apigee](https://www.googlecloudcommunity.com/gc/Apigee/bd-p/cloud-apigee).

## License

This material is [Copyright 2023 Google LLC](./NOTICE)
and is licensed under the [Apache 2.0 License](LICENSE).