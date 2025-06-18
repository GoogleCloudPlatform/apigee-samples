# Cloud Logging

This example explores how you can send custom logging messages from Apigee into
[Google Cloud Logging](https://cloud.google.com/logging/docs/overview)

## About logging, analytics and other data collection mechanisms

It is important to know that Apigee collects and analyzes, by default, a lot of important [API metrics](https://cloud.google.com/apigee/docs/api-platform/analytics/analytics-services-overview#what-kind-of-data-is-collected-and-analyzed) within the Apigee Analytics feature set and these can be consumed in many ways - native dashboards, custom reports, metric API, export to BigQuery or Cloud Storage and others. For many users, depending on the use-case and objectives, this native set of analytics is enough and API request/response logging might not even be needed.

But if you need per API-call specific logging of specific API request/response fields, Apigee/custom flow variables, proxy variables and other information, this accelerator will focus on the [Message Logging](https://cloud.google.com/apigee/docs/api-platform/reference/policies/message-logging-policy) policy and how to export log messages to Google Cloud Logging.

## How it works

This simple API proxy is basically a transparent pass-through. It will invoke a sample target endpoint. But, it is configured to send a log message to Cloud Logging, for each API request it handles.

It is configured to use [Google Authentication](https://cloud.google.com/apigee/docs/api-platform/security/google-auth/overview). The proxy will use credentials corresponding to the identity of a [service account](https://cloud.google.com/iam/docs/understanding-service-accounts) we'll create and that has permissions to create logging entries (`logging.logEntries.create`) in this project's Cloud Logging.

## Implementation on Apigee

The MessageLogging policy is attached in the
[PostClientFlow](https://cloud.google.com/apigee/docs/api-platform/fundamentals/what-are-flows#designingflowexecutionsequence-havingcodeexecuteaftertheclientreceivesyourproxysresponsewithapostclientflow). While
one can add this policy to any point of the request or response flow, the PostClientFlow is typically
the best place to add a MessageLogging policy. At that point, the proxy will have all the context
associated to the call, and, the log is written after the actual API response is sent to the API client,
which means the client does not incur any latency associated to the log write.  In this example, the proxy will log
flow variables, request content, response content, static values, etc. The policy is quite flexible in
terms of what it can log.  It is also worth noting that it is quite common to add the MessageLogging
policy to Shared Flows for standardization across multiple APIs. In this example, just for simplicity, it will be added
directly to the sample proxy.

## Screencast

[![Alt text](https://img.youtube.com/vi/p-ZbUExQgzw/0.jpg)](https://www.youtube.com/watch?v=p-ZbUExQgzw)

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)

2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance

3. A Linux-based shell with bash, and the following tools available in your terminal's $PATH:
    * [gcloud CLI](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm

   Cloud Shell is sufficient, and has all of these preconfigured, but you can use your own workstation.

4. Make sure your Google Cloud user has all the relevant IAM roles for executing this script
    * `roles/iam.serviceAccountCreator`
    * `roles/resourcemanager.projectIamAdmin`
    * `roles/apigee.apiAdminV2`

   The way roles work in Google Cloud: think of them as a way to group a set of related permissions that are often used together. For example, the [iam.serviceAccountCreator role](https://cloud.google.com/compute/docs/access/iam#iam.serviceAccountCreator) grants these permissions:
      * iam.serviceAccounts.create
      * iam.serviceAccounts.get
      * iam.serviceAccounts.list
      * resourcemanager.projects.get
      * resourcemanager.projects.list

   A user that has project Owner or project Editor role has [thousands of
   permissions](https://cloud.google.com/iam/docs/understanding-roles#basic),
   including the above. If your user is not Editor or Owner, you will need an
   Editor or Owner or other privileged account to grant the additional roles to
   your user, before proceeding with this exercise.

5. You should ensure the Cloud Logging API is enabled in your GCP project, or that you have the permissions to enable the API in your project.

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=cloud-logging/docs/cloudshell-tutorial.md)

## Manual Setup instructions

If you do not wish to use the Cloudshell tutorial link provided above, you can follow these steps, on
your own.

1. Clone the apigee-samples repo, and switch the cloud-logging directory

   ```bash
   git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
   cd apigee-samples/cloud-logging
   ```

2. Edit the `env.sh` and configure the required environment variables:

   * `PROJECT` the project where your Apigee organization is located
   * `APIGEE_ENV` the Apigee environment where the demo resources should be created
   * `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV

   Now source the `env.sh` file

   ```bash
   source ./env.sh
   ```

3. Authenticate to Google Cloud, if you have not already done so in this shell.

   ```bash
   gcloud auth login
   ```

4. Check the roles on your account:

   ```bash
   ./check-role.sh
   ```

   This script will show your identity and the roles associated to your identity.

   If you have editor or owner roles, you will be able to proceed. If you do not have these roles, but
   you have these roles:
    * `roles/iam.serviceAccountCreator`
    * `roles/resourcemanager.projectIamAdmin`
    * `roles/apigee.apiAdminV2`

   ...then you can use this sample, but you need to insure some other person has enabled the Cloud
   Logging API on your project. We will check that the Logging API is enabled in the next step.

5. Check that the logging API is enabled.

Owners or Editors on a Google Cloud Project must enable individual services, for
them to be available.  Let's check that the Logging API is enabled.

   ```bash
   ./check-required-services.sh
   ```

* If this indicates that the logging API is already enabled on the project, you can proceed.

* If the logging API is not enabled, but you have editor or owner role (as shown in the previous
     step), then you will enable the logging API in the next step.

* If the logging API is not enabled, and you do not have editor or owner role, then you need to
     stop, and find someone who can enable that API on your GCP project, before proceeding here.

5. Deploy Apigee API proxy

   ```bash
   ./deploy-cloud-logging.sh
   ```

   You should see happy messages.

## Test the API & Logging

Generate a few sample requests to the deployed API Proxy.

```bash
curl -i https://$APIGEE_HOST/v1/samples/cloud-logging
```

> _If you want, consider also checking the call in the [Debug](https://cloud.google.com/apigee/docs/api-platform/debug/trace) view_

After issuing some calls, let's confirm the configured variables / values set on the Message Logging policy were successfully written to Cloud Logging with

```bash
gcloud logging read "logName=projects/$PROJECT/logs/apigee"
```

Cloud Logging is quite powerful. Few free to navigate to the [Logs Explorer UI
in the GCP Console](https://console.cloud.google.com/logs/query) (_Logging_
Product Page in the console) and explore additional features such as filters,
custom searches, custom alerts, saved queries, and much more

If you are so inclined, you can modify the apiproxy, introducing new policies,
or modifying the existing MessageLogging policy. Re-deploy the updated version,
and then re-run your tests, and re-examine the logs.

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your
`env.sh` script, and then run

```bash
./clean-up-cloud-logging.sh
```
