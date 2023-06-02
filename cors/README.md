# Integrated Developer Portal

This sample lets you create an API that is protected against cross-origin-requests (CORS)

## About CORS Security

Talk about what CORS is, and why it is important to protect against it

Talk about Apigee's CORS policy, and how Apigee protects against CORS

## Implementation on Apigee 

The Apigee proxy sample only a single policy; a CORS policy to protect against CORS attacks

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

# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions in Cloud Shell. Alternatively, follow the instructions below.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=cors/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch to the cors directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/cors
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

Next, let's deploy some CORS protected Apigee sample proxy

```bash
./deploy-cors.sh
```

---
## Test Integrated Developer Portal

Now that our API proxy is deployed, let's enable the debugger so we can see requests as they come through:
1. Click into the sample-cors proxy
2. Navigate to the debug section
3. Choose to start a debug session for the currently deployed proxy version

With the proxy debugger still running, call the sample CORS proxy from a cross origin client:
1. Navigate to an online HTTP request sending service such as https://cors-tester.org. The requests need to be sent from an online service and should not be sent from your local machine.
2. From https://cors-tester.org enter your proxy's URL, https://\[APIGEE_HOST\]/v1/sample/cors into the URL input box. Leave all other fields at their default values
3. Click send and view the response. You should see 200 response, meaning our CORS policy is working as expected and our test was a success!
4. Navigate to the Apigee debugger. OPTIONS? SUCCESS?

Start Apigee Debugger > Go to cors-tester.org > Enter in the information > test

Should retun 200 response message > If this wasn't CORS protected the request would fail

Further notes on implmentation:
1. Can restrict domains
2. Can restrict headers and other pieces of information
3. Learn more about the CORS policy here

## Conclusion & Cleanup

To clean up the artifacts created source your `env.sh` script and run the following to delete your sample CORS proxy:

```bash
./clean-up-cors.sh
```
