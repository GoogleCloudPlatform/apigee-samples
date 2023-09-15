# Basic Quota

This sample shows how to implement a basic API consumption limit using Apigee's [Quota](https://cloud.google.com/apigee/docs/api-platform/reference/policies/quota-policy) policy.

## About quotas

The Quota policy enforces consumption limits on client apps by maintaining a counter that tallies incoming requests. The counter can tally API calls for any identifiable entity, including apps, developers, API keys, access tokens, and so on. Usually, API keys are used to identify client apps. This policy should be used to enforce business contracts or SLAs with developers and partners, rather than for operational traffic throttling.

## How it works

A quota is an allotment of request messages that an API proxy can handle over a time period, such as minute, hour, day, week, or month. The Quota policy enables API providers to enforce limits on the number of API calls made by apps over this time period.

When an API proxy reaches its quota limit, subsequent API calls are rejected; Apigee returns an error for every request that exceeds the quota.

You can set the quota to be the same for all apps accessing the API proxy, or you can set the quota based on:

* The [API product](https://cloud.google.com/apigee/docs/api-platform/publish/what-api-product) that contains the API proxy
* The [app](https://cloud.google.com/apigee/docs/api-platform/publish/creating-apps-surface-your-api) that makes the request
* The app [developer](https://cloud.google.com/apigee/docs/api-platform/publish/adding-developers-your-api-product)
* Many other criteria

This sample shows how to enforce a dynamic quota as defined by the API product. Two products are created with different quotas to demonstrate how different consumption tiers can be configured for the same API.

The Quota policy contains many options to control the desired behavior. For more information see the Quota policy [reference](https://cloud.google.com/apigee/docs/api-platform/reference/policies/quota-policy).

## Implementation on Apigee

This sample uses a [VerifyAPIKey](https://cloud.google.com/apigee/docs/api-platform/reference/policies/verify-api-key-policy) policy to identify the calling application and the API product associated with the proxy. The Quota policy is configured to enforce the limit and time interval defined in the API product. An [AssignMessage](https://cloud.google.com/apigee/docs/api-platform/reference/policies/assign-message-policy) policy is used to set a success response that includes the current value of the counter vs. the allowed limit. A [RaiseFault](https://cloud.google.com/apigee/docs/api-platform/reference/policies/raise-fault-policy) policy is used to return a custom error payload when the quota is exceeded.

## Screencast

[![Alt text](https://img.youtube.com/vi/ep7h_tGHtiw/0.jpg)](https://www.youtube.com/watch?v=ep7h_tGHtiw)

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Access to deploy proxies, create products, apps and developers in Apigee
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm
# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=basic-quota/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the `apigee-samples` repo, and switch the `basic-quota` directory


```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/basic-quota
```

2. Edit `env.sh` and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee API proxies, products and apps

```bash
./deploy-basic-quota.sh
```

## Testing the Quota Proxy
To run the tests, first retrieve Node.js dependencies with:
```
npm install
```
Ensure the following environment variables have been set correctly:
* `PROXY_URL`
* `CLIENT_ID_1`
* `CLIENT_ID_2`

and then run the tests:
```
npm run test
```

## Example Requests
To manually test the proxy, make requests using the API keys created by the deploy script.

If the deployment has been successfully executed, you will see two products (`basic-quota-trial` & `basic-quota-premium`) and two corresponding apps (`basic-quota-trial-app` & `basic-quota-premium-app`) created for testing purposes. Instructions for how to find
application credentials can be found [here](https://cloud.google.com/apigee/docs/api-platform/publish/creating-apps-surface-your-api#view-api-key).

The requests can be made like this:
```
curl https://$APIGEE_HOST/v1/samples/basic-quota?apikey=$CLIENT_ID_1
```

When testing with the `basic-quota-trial-app` key, the response will show 10 requests _per minute_ allowed. Each subsequent response will increment the counter until the quota is exceeded.

When testing with the `basic-quota-premium-app` key, the response will instead show 1000 requests _per hour_.

## Cleanup

If you want to clean up the artefacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-basic-quota.sh
```