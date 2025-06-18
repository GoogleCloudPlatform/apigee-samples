# Java Callout
This example provides a simple Apigee Proxy that uses a Java Callout [Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/java-callout-policy).

## About the Java Callout Policy
The Java Callout Policy offers a way to extend the capabilities of your API proxies by allowing you to execute custom Java code within the proxy flow. This policy enables users to implement specialized logic that isn't covered by built-in Apigee policies using Java Code. You can leverage a Java Callout to manipulate request and response messages, read and set flow variables, perform custom error handling, or specific calculations. 

You'll package your custom Java code into a JAR file and then deploy it to Apigee. The Java Callout policy then references this JAR, allowing your code to interact with the current API proxy context.

Refer to Java Callout Policy Documentation for supported Java version information: [Java Callout Policy Documentation](https://cloud.google.com/apigee/docs/api-platform/reference/policies/java-callout-policy#what)

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

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=java-callout/docs/cloudshell-tutorial.md)

## Setup Instructions
1. Clone the apigee-samples repo, and switch the java-callout directory
  ```bash
  git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
  cd apigee-samples/java-callout
   ```

2. Edit the `env.sh` and configure the required environment variables:

   * `PROJECT` the project where your Apigee organization is located
   * `APIGEE_ENV` the Apigee environment where the demo resources should be created
   * `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV

   Now source the `env.sh` file

   ```bash
   source ./env.sh
   ```

3. Deploy Apigee API proxy

   ```bash
   ./deploy-java-callout.sh
   ```

## Test the API
Make a call to the deployed java-callout proxy
  ```bash
   curl -i https://$APIGEE_HOST/v1/samples/java-callout
   ```
> _If you want, consider also checking the call in the [Debug](https://cloud.google.com/apigee/docs/api-platform/debug/trace) view_

***Successful deployment of the proxy will return a “Hello, World!” response.***

## Cleanup
If you want to clean up the artifacts from this example in your Apigee Organization, first source your
`env.sh` script, and then run
```bash
./clean-up-java-callout.sh
```
