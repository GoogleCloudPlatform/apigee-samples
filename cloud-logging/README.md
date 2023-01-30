# Cloud Logging

This example explores how you can send custom logging messages from Apigee into [Google Cloud Logging](https://cloud.google.com/logging/docs/overview)

## About logging, analytics and other data collection mechanisms

It is important to know that Apigee collects and analyzes, by default, a lot of important [API metrics](https://cloud.google.com/apigee/docs/api-platform/analytics/analytics-services-overview#what-kind-of-data-is-collected-and-analyzed) within the Apigee Analytics feature set and these can be consumed in many ways - native dashboards, custom reports, metric API, export to BigQuery or Cloud Storage and others. For many users, depending on the use-case and objectives, this native set of analytics is enough and API request/response logging might not even be needed.

But if you need per API-call specific logging of specific API request/response fields, Apigee/custom flow variables, proxy variables and other information, this accelerator will focus on the [Message Logging](https://cloud.google.com/apigee/docs/api-platform/reference/policies/message-logging-policy) policy and how to export log messages to Google Cloud Logging.

## How it works

This simple API proxy is basically transparent and will hit a sample target endpoint. But, it will be configured to use [Google Authentication](https://cloud.google.com/apigee/docs/api-platform/security/google-auth/overview). The proxy will use credentials corresponding to the identity of a [service account](https://cloud.google.com/iam/docs/understanding-service-accounts) we'll create and that has permissions to create logging entries (`logging.logEntries.create`) in this project's Cloud Logging. 

## Implementation on Apigee 

The MessageLogging policy will be placed at the [PostClientFlow](https://cloud.google.com/apigee/docs/api-platform/fundamentals/what-are-flows#designingflowexecutionsequence-havingcodeexecuteaftertheclientreceivesyourproxysresponsewithapostclientflow). While one can add this policy to any point of the request or response flow, the PostClientFlow is typically the best place to add it because we'll have all the context of the call and it is executed after the actual API response is sent to the API client. 
As an example, we'll log flow variables, request content, reponse content, static values, etc. The policy is quite flexible in terms of what it can log.
It is also worth noting that it is quite common to add the MessageLogging policy to Shared Flows for standardization across multiple APIs, but in this example it will be added directly to the sample proxy.

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm
4. Make sure you have all the relevant IAM roles for executing this script
    * `roles/iam.serviceAccountCreator`
    * `roles/resourcemanager.projectIamAdmin`
    * `roles/apigee.apiAdminV2`

# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=cloud-logging/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the cloud-logging directory


```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd cloud-logging
```

2. Edit the `env.sh` and configure the ENV vars

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee API proxy

```bash
./deploy-cloud-logging.sh
```

## Test the API & Logging

Generate a few sample requests to the deployed API Proxy.

```
curl  https://$APIGEE_HOST/v1/samples/cloud-logging
```
> _If you want, consider also checking the call in the [Debug](https://cloud.google.com/apigee/docs/api-platform/debug/trace) view_

After issuing some calls, let's confirm the configured variables / values set on the Message Logging policy were successfully writen to Cloud Logging with 

```
gcloud logging read "logName=projects/$PROJECT/logs/apigee"
```

Cloud Logging is quite powerful. Few free to navigate to its UI in the GCP Console (_Logging_ Product Page in the console) and explore additional features such as filters, custom searchs, custom alerts and much more

## Cleanup

If you want to clean up the artefacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-cloud-logging.sh
```

## Not Google Product Clause

This is not an officially supported Google product, nor is it part of an
official Google product.

## Support

If you need support or assistance, you can try inquiring on [Google Cloud Community
forum dedicated to Apigee](https://www.googlecloudcommunity.com/gc/Apigee/bd-p/cloud-apigee).

## License

This material is [Copyright 2023 Google LLC](../NOTICE)
and is licensed under the [Apache 2.0 License](../LICENSE).