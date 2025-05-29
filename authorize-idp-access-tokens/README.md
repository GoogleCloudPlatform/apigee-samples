# Authorize IdP Access Token

This sample allows you to authorize JWT access tokens issued by an OpenID (OIDC) Identity Provider.

## About OIDC

[OpenID Connect](https://openid.net/specs/openid-connect-core-1_0.html) is an identity layer on top of the OAuth 2.0 protocol. It allows Relying Parties (clients) to verify the identity of an End-User based on the authentication performed by an Authorization Server, and to obtain profile information about the End-User.

## About JWT Access Tokens

JWT tokens are compact and self-contained way to represent and transmit claims between two parties based on the [RFC7519](https://www.rfc-editor.org/rfc/rfc7519) standard. These claims are encoded in JSON format and this data can be digitally signed, encrypted, and/or integrity protected.

JWT tokens are used by [OpenID Connect](https://openid.net/specs/openid-connect-core-1_0.html) compliant identity providers for:

* Authentication: After an End-User has been successfully authenticated, an authorization server will issue a JWT Id Token to store End-User claims.
* Authorization: A Relying Party (client application) may request access to protected resources on behalf of an End-User by presenting an authorization grant to obtain an Access Token. OIDC Identity providers may support access tokens as JWTs based on the [RFC9068](https://datatracker.ietf.org/doc/rfc9068/) spec.
* Information exchange: JWTs can be used to securely share structured (JSON) and arbitrary / binary data (JWE).

## Purpose

With this example you'll be able to:

* Import Client ID and Secret representing a Relying Party or Client Application from an OIDC Identity Provider that supports JWT access tokens based on [RFC9068](https://datatracker.ietf.org/doc/rfc9068/)
* Validate JWT access tokens
* Identify the Client Application in Apigee

## Components

This implementation includes two artifacts:

* Authorize IdP Access Tokens Shared Flow: includes policies to validate JWT access tokens and identify client Apps.
* Test Proxy: A proxy that references the previous shared flow using a Flow Callout policy.
* Mock Authorization Server: Included to facilitate the testing experience. You can also bring your own OIDC Identity provider to test this sample.
* Deployment and cleanup scripts

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
5. Obtain a Client ID, a Client Secret, and a JWT access token from an OIDC Identity Provider (you'll be using the values during the quickstart)

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=authorize-idp-access-tokens/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the authorize-idp-access-tokens directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/authorize-idp-access-tokens
```

2. Edit the `env.sh` and configure the ENV vars. If you don't set variables that are marked as `Optional`, then the deploy script will also provision a mock OIDC authorization server that will allow you to issue JWT access tokens to test this sample

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `APIGEE_HOST` the hostname used to expose an Apigee environment group to the Internet
* `JWKS_URI` (Optional) the [JWKS URI](https://openid.net/specs/openid-connect-core-1_0.html#RotateSigKeys) from the OIDC Identity Provider that will issue JWT access tokens
* `TOKEN_ISSUER` (Optional) the [Issuer Identifier](https://openid.net/specs/openid-connect-core-1_0.html#IssuerIdentifier) from the OIDC Identity Provider that will issue JWT access tokens
* `TOKEN_AUDIENCE` (Optional) the Token Audiences as defined in the OIDC identity provider that will issue JWT access tokens
* `TOKEN_CLIENT_ID_CLAIM` (Optional) the name of the claim that will be used to store the client application identifier in the JWT access token (examples `azp` or `client_id`)
* `IDP_APP_CLIENT_ID` (Optional) the Client ID issued by the Identity Provider. This value needs to be imported in Apigee to be able to identify the client app traffic
* `IDP_APP_CLIENT_SECRET` (Optional) the Client Secret issued by the Identity Provider. This value is not used in this sample therefore it can also be an arbitrary value

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee artifacts and environment configuration

```bash
./deploy-authorize-idp-access-tokens.sh
```

## Testing the sample with Google's OAuth Playground

If you didn't set values for `Optional` environment variables during the setup step, then the deploy script will generate a URI to the Google OAuth Playground with custom configuration to target a mock Authorization Server. To test the sample proxy with a JWT access token, navigate to this URI on a separate browser tab and complete the following steps:

1. After landing on the Google OAuth Playground, accept the use of a custom OAuth configuration by clicking the green "OK! That's fine." button in the warning popup.

2. On the left panel there's a 3-step wizard to obtain access tokens from a mock authorization server. At the bottom section of Step 1 "Select & authorize APIs", input any, some, or all of the allowed scopes (comma separated if more than one) and press the Authorize APIs button. The allowed scopes are `READ`, `WRITE`, and `ACTION`.

3. On Step 2 "Exchange authorization code for tokens", press the blue "Exchange authorization code for tokens" button. On the "Request / Response" section at the center of the screen you'll be able to retrieve the value of the JWT access token issued by the mock authorization server. You can copy this value to inspect it further using the JWT debugger tool at [JWT.io](https://jwt.io/).

4. On Step 4 "Configure request to API", copy the sample request URI provided by the deploy script output and paste it in the Request URI value of the wizard and leave the rest of  settings with default values. Finally, press the blue "Send the request" button to send a request to the sample proxy that will verify the JWT access token issued by the mock authorization server.

## Testing the sample with your own OIDC Identity Provider

If you set `Optional` environment variables with values from your own OIDC Identity Provider during the setup step, then obtain a JWT access token by completing an authorization flow of your choice. Set the JWT access token as a value of the `IDP_TOKEN` environment variable and send a cURL request as shown below:

```bash
IDP_TOKEN=REPLACE_WITH_IDP_ACCESS_TOKEN
curl -v https://$APIGEE_HOST/v1/samples/authorize-idp-access-tokens -H "Authorization: Bearer $IDP_TOKEN"
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-deploy-authorize-idp-access-tokens.sh
```
