# Extract Variables and Assign Message

This sample shows how to easily extract fields from an XML and JSON response. This sample leverages the following policies::

* [Extract Variables](https://cloud.google.com/apigee/docs/api-platform/reference/policies/extract-variables-policy) policy to extract subsets of data from the response body.
* [XML to JSON](https://cloud.google.com/apigee/docs/api-platform/reference/policies/xml-json-policy) policy to convert the XML response from the target server to JSON.
* [Assign Message](https://cloud.google.com/apigee/docs/api-platform/reference/policies/assign-message-policy?hl=en) policy to set the response Headers with the extracted fields and other [flow variables](https://cloud.google.com/apigee/docs/api-platform/fundamentals/introduction-flow-variables).

## About the extract variables policy

The ExtractVariables policy extracts content from a request or response and sets the value of a variable to that content. You can extract any part of the message, including headers, URI paths, JSON/XML payloads, form parameters, and query parameters. The policy works by applying a text pattern to the message content and, upon finding a match, sets a variable with the specified message content.

While you often use ExtractVariables to extract information from a request or response message, you can also use it to extract information from other sources, including entities created by the AccessEntity policy, XML objects, or JSON objects.

After extracting the specified message content, you can reference the variable in other policies as part of processing a request and response.

## How it works

API developers build API proxies that behave differently based on the content of messages, including headers, URI paths, payloads, and query parameters. Often, the proxy extracts some portion of this content for use in a condition statement. Use the ExtractVariables policy to do this.

When defining the [ExtractVariables](https://cloud.google.com/apigee/docs/api-platform/reference/policies/extract-variables-policy?hl=en) policy, you can choose:

* Names of the variables to be set
* Source of the variables
* How many variables to extract and set

When executed, the policy applies a text pattern to the content and, upon finding a match, sets the value of the designated variable with the content. Other policies and code can then consume those variables to enable dynamic behavior or to send business data to Apigee API Analytics.

## Implementation on Apigee

This sample uses the the [Apigee Mock Target API](https://apidocs.apigee.com/docs/mock-target/1/overview) as backend server, providing an XML response with the following fields:

```xml
<?xml version="1.0" encoding="UTF-8"?> <root><city>San Jose</city><firstName>John</firstName><lastName>Doe</lastName><state>CA</state></root>
```

We use the  [Extract Variables](https://cloud.google.com/apigee/docs/api-platform/reference/policies/extract-variables-policy) policy as a first step to extract subsets of data from the XML response body.
Later on we leverage the [XML to JSON](https://cloud.google.com/apigee/docs/api-platform/reference/policies/xml-json-policy) policy to convert the XML response from the target server to JSON.
We use again the  [Extract Variables](https://cloud.google.com/apigee/docs/api-platform/reference/policies/extract-variables-policy) policy to extract subsets of data from the now converted JSON string.
Finally we use the [Assign Message](https://cloud.google.com/apigee/docs/api-platform/reference/policies/assign-message-policy?hl=en) policy to set the response headers with the extracted fields and other [flow variables](https://cloud.google.com/apigee/docs/api-platform/reference/variables-reference).

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Access to deploy proxies in Apigee
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=extract-variables/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the `apigee-samples` repo, and switch the `extract-variables` directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/extract-variables
```

2. Edit `env.sh` and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee API proxies:

```bash
./deploy.sh
```

## Example Requests

To manually test the proxy, make requests using curl:

```bash
curl -v https://$APIGEE_HOST/v1/samples/extract-variables
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```
