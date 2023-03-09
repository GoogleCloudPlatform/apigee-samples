# Client Credentials Grant Type with OAuth2 scopes

This sample lets you request an OAuth token from Apigee using the OAuth 2.0 client credentials grant type flow and limit access using [OAuth2 scopes](https://cloud.google.com/apigee/docs/api-platform/security/oauth/working-scopes). 

## About client credentials

Most typically, this grant type is used when the app is also the resource owner. For example, an app may need to access a backend cloud-based storage service to store and retrieve data that it uses to perform its work, rather than data specifically owned by the end user. This grant type flow occurs strictly between a client app and the authorization server. An end user does not participate in this grant type flow. 

### What is OAuth2 scope?

OAuth 2.0 scopes provide a way to limit the amount of access that is granted to an access token. For example, an access token issued to a client app may be granted READ and WRITE access to protected resources, or just READ access. You can implement your APIs to enforce any scope or combination of scopes you wish. So, if a client receives a token that has READ scope, and it tries to call an API endpoint that requires WRITE access, the call will fail.

In this topic, we'll discuss how scopes are assigned to access tokens and how Apigee enforces OAuth 2.0 scopes. After reading this topic, you'll be able to use scopes with confidence.

## How it works

With the client credentials grant type flow, the client app requests an access token directly by providing its client ID and client secret keys. These keys are generated when you create a Developer App in Apigee. Apigee validates the credentials and returns an access token to the client. The client can then make secure calls to the resource server.

The API is called like this, where the client ID and secret are Base64-encoded and used in the Basic Auth header:

```
curl -H "Authorization: Basic <base64-encoded key:secret>" https://your-api-url.com/oauth/token?grant_type=client_credentials
```

## Implementation on Apigee 

The client credentials sample uses one policy that executes on Apigee : An OAuthV2 policy to generate the access token. The policy is attached to the `/token` endpoint (a custom flow on Apigee). 

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

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=oauth-client-credentials-with-scope/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the oauth-client-credentials-with-scope directory


```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/oauth-client-credentials-with-scope
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
./deploy-oauth-client-credentials-with-scope.sh
```

## Testing the Client Credentials Proxy
To run the tests, first retrieve Node.js dependencies with:
```
npm install
```
Ensure the following environment variables have been set correctly:
* `PROXY_URL`
* `APP_READ_SCOPE_CLIENT_ID`
* `APP_READ_SCOPE_CLIENT_SECRET`
* `APP_WRITE_SCOPE_CLIENT_ID`
* `APP_WRITE_SCOPE_CLIENT_SECRET`

and then run the tests:
```
npm run test
```

## Example Requests
For additional examples, including negative test cases,
see the [auth-schemes.feature](./test/integration/features/oauth-client-credentials-with-scope.feature) file.

## Test the APIs

The script that deploys the Apigee API proxies will print two sets of cURL commands. 

First set is with the a token with `read` access. You will find that it only works with the GET call. The POST call will fail. This is because of the insuffient scope to make a POST call to that resource.

Similarly, the second set of cURL commands include a token with `write` access. With this token, both the cURL should return a successful response.

## Cleanup

If you want to clean up the artefacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-oauth-client-credentials-with-scope.sh
```
