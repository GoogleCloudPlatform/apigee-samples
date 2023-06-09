# CORS Security

This sample lets you create an API that uses the cross-origin resource sharing (CORS) mechanism to allow requests from external webpages and applications

## About CORS Security

CORS is a standard solution to the [same-origin policy](https://en.wikipedia.org/wiki/Same-origin_policy) that is enforced by all browsers. CORS allows you to opt-in to serve requests from non-origin requests.

Apigee's [CORS policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/cors-policy) offers a simple CORS solution for your APIs. Consider this policy if you desire to call your Apigee proxy from a different domain. CORS policies can also allow/deny other request parameters such as the method or header.

## Implementation on Apigee 

The Apigee proxy sample is a no-target proxy with only a single policy; a CORS policy that allows access for all cross-origin domains

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

2. Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

3. Edit the `env.sh` and configure the ENV vars

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

## Deploy Apigee components

Next, let's deploy some CORS protected Apigee sample proxy

```bash
./deploy-cors.sh
```

---
## Test CORS Proxy

Now that our API proxy is deployed, let's enable the debugger so we can see requests as they come through:
1. Navigate to the [Apigee homepage](https://apigee.google.com). Go to Develop > API Proxies and click into the sample-cors proxy
2. Navigate to the debug tab
3. Choose to start a debug session for the currently deployed proxy version

With the proxy debugger still running, call the sample CORS proxy from a cross origin client:
1. Navigate to an online HTTP request service such as [test-cors.org](https://test-cors.org). The requests need to be sent from an online service and should not be sent from your local machine.
2. From [test-cors.org](https://test-cors.org) find the Remote URL field and enter in your proxy's URL, https://\[APIGEE_HOST\]/v1/samples/cors. Leave all other fields at their default values
3. Click the Send Request button and view the response. You should see 200 response, meaning our CORS policy is working as expected and our test was a success!
4. Navigate to the Apigee debugger. You should see a 200 response there as well.

### Further Notes on CORS
Apigee's CORS policy can do much more than open up your APIs for cross-origin traffic like we did in this sample. It is important to understand how it can be used to protect your APIs from unwanted traffic and attacks. Please read the policy documentation to understand concepts like [allowed origins](https://cloud.google.com/apigee/docs/api-platform/reference/policies/cors-policy#allow-origins) and [maximum  age](https://cloud.google.com/apigee/docs/api-platform/reference/policies/cors-policy#max-age)

## Conclusion & Cleanup

Congratulations! You've successfully created a CORS secured Apigee API.

To clean up the artifacts created source your `env.sh` script and run the following to delete your sample CORS proxy:

```bash
./clean-up-cors.sh
```
