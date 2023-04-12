# Client Credentials Grant Type

This sample lets you request an OAuth token from Apigee using the OAuth 2.0 client credentials grant type flow. 

## About client credentials

Most typically, this grant type is used when the app is also the resource owner. For example, an app may need to access a backend cloud-based storage service to store and retrieve data that it uses to perform its work, rather than data specifically owned by the end user. This grant type flow occurs strictly between a client app and the authorization server. An end user does not participate in this grant type flow. 

## How it works

With the client credentials grant type flow, the client app requests an access token directly by providing its client ID and client secret keys. These keys are generated when you create a Developer App in Apigee. Apigee validates the credentials and returns an access token to the client. The client can then make secure calls to the resource server.

The API is called like this, where the client ID and secret are Base64-encoded and used in the Basic Auth header:

```
curl -H "Authorization: Basic <base64-encoded key:secret>" https://your-api-url.com/oauth/token?grant_type=client_credentials
```

## Implementation on Apigee 

The client credentials sample uses one policy that executes on Apigee : An OAuthV2 policy to generate the access token. The policy is attached to the `/token` endpoint (a custom flow on Apigee). 

### Screencast

[![Alt text](https://img.youtube.com/vi/8DWRIPuJxvk/0.jpg)](https://www.youtube.com/watch?v=8DWRIPuJxvk)

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

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=oauth-client-credentials/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the oauth-client-credentials directory


```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/oauth-client-credentials
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
./deploy-oauth-client-credentials.sh
```

## Testing the Client Credentials Proxy
To run the tests, first retrieve Node.js dependencies with:
```
npm install
```
Ensure the following environment variables have been set correctly:
* `PROXY_URL`
* `APP_CLIENT_ID`
* `APP_CLIENT_SECRET`

and then run the tests:
```
npm run test
```

## Example Requests
For additional examples, including negative test cases,
see the [oauth-client-credentials.feature](./test/integration/features/oauth-client-credentials.feature) file.

### OAuth Bearer Token (RFC 6749)
First obtain a short-lived opaque access token using the token endpoint. Instructions for how to find
application credentials can be found [here](https://cloud.google.com/apigee/docs/api-platform/publish/creating-apps-surface-your-api#view-api-key).
If the deployment has been successfully executed, you will see the `oauth-client-credentials-app` created for testing purposes.
```
curl -v POST https://$APIGEE_HOST/v1/samples/oauth-client-credentials/token -u $APP_CLIENT_ID:$APP_CLIENT_SECRET -d "grant_type=client_credentials"
```
> _Note: Under normal circumstances, avoid providing secrets on the command itself using `-u`_

Copy the value of the `access_token` property from the response body of the previous request and include it in the following request:
```
curl -v GET https://$APIGEE_HOST/v1/samples/oauth-client-credentials/resource -H "Authorization: Bearer access_token"
```

## Cleanup

If you want to clean up the artefacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-oauth-client-credentials
```
