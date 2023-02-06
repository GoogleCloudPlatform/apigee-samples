# Authorize IdP Access Token

This sample allows you to authorize JWT access tokens issued by an OIDC compliant identity provider.

## About JWT Access Tokens

JWT tokens are compact and self-contained way to represent and transmit claims between two parties based on the [RFC7519](https://www.rfc-editor.org/rfc/rfc7519) standard. These claims are encoded in JSON format and this data can be digitally signed, encrypted, and/or integrity protected.

JWT tokens are used by [OIDC](https://openid.net/specs/openid-connect-core-1_0.html) compliant identity providers for:
* Authentication: After an End-User has been successfully authenticated, an authorization server will issue a JWT Id Token to store End-User claims.
* Authorization: A Relying Party (client application) may request access to protected resources on behalf of an End-User by presenting an authorization grant to obtain an Acccess Token. Identity providers may support access tokens as JWTs based on the [RFC9068](https://datatracker.ietf.org/doc/rfc9068/) spec.
* Information exchange: JWTs can be used to securely share structured (JSON) and arbitrary / bynary data (JWE).

## Purpose

With this example you'll be able to:

* Import Client IDs and Secrets from an Identity Provider into Apigee as Developer App credentials
* Validate JWT access tokens issued by an Identity Provider that supports [OIDC](https://openid.net/specs/openid-connect-core-1_0.html) or [RFC9068](https://datatracker.ietf.org/doc/rfc9068/)
* Identify the Client App in Apigee

## Components

This implementation includes two artifacts:

* Authorize IdP Access Tokens Shared Flow: includes policies to valiate JWT access tokens an identify client Apps.
* Test Proxy: A proxy that references the previous shared flow using a Flow Callout policy.

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
5. Configure and obtain Client App credentials from the Identity Provider. These usually are client identifier and secret / password credential pairs.

6. Obtain a JWT access token from the Identity Provider. The grant type and method to obain the access token is specific to each IdP. However, it is common for Identity Providers to support the client_credentials grant type to issue access tokens to authorized applications.

# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=authorize-idp-access-tokens/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the authorize-idp-access-tokens directory


```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/authorize-idp-access-tokens
```

2. Edit the `env.sh` and configure the ENV vars

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `JWKS_URI` the [JWKS URI](https://openid.net/specs/openid-connect-core-1_0.html#RotateSigKeys) from the OIDC identity provider that will issue JWT access tokens
* `TOKEN_ISSUER` the [Issuer Identifier](https://openid.net/specs/openid-connect-core-1_0.html#IssuerIdentifier) from the OIDC Identity provider that will issue JWT access tokens
* `TOKEN_AUDIENCE` the Token Audiences as defined in the OIDC identity provider that will issuee JWT access tokens
* `TOKEN_CLIENT_ID_CLAIM` the name of the claim that will be used to store the client application identifier in the JWT access token (examples `azp` or `client_id`)
* `IDP_APP_CLIENT_ID` the Client ID issued by the Identity Provider. This value needs to be imported in Apigee to be able to identify the client app traffic
* `IDP_APP_CLIENT_SECRET` the Client Secret issued by the Identity Provider. This value is not used in this sample therefore it can also be an arbitraty value


Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee artifacts and environment configuration

```bash
./deploy-authorize-idp-access-tokens.sh
```

## Testing with sample request

First, obtain an access token from the OIDC Identity provider using the Client ID and Secret values that were imported into Apigee. Set the token as an environment variable and send a cURL request as shown below:

```
IDP_TOKEN=REPLACE_WITH_IDP_ACCESS_TOKEN
curl -v https://$APIGEE_HOST/v1/samples/authorize-idp-access-tokens -H "Authorization: Bearer $IDP_TOKEN"
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-deploy-authorize-idp-access-tokens.sh
```
