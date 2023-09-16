# Authorize IdP Access Token

---
This sample allows you to authorize JWT access tokens minted by an OIDC compliant identiy provider.

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'authorize-idp-access-tokens' drirectory in the Cloud shell.

```sh
cd authorize-idp-access-tokens
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="authorize-idp-access-tokens/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

> _Note: If you prefer to use a mock authorization server to test this sample, then don't provide any of the variables marked as `Optional`._

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `APIGEE_HOST` the hostname used to expose an Apigee environment group to the Internet
* `JWKS_URI` (Optional) the [JWKS URI](https://openid.net/specs/openid-connect-core-1_0.html#RotateSigKeys) from the OIDC Identity Provider that will issue JWT access tokens
* `TOKEN_ISSUER` (Optional) the [Issuer Identifier](https://openid.net/specs/openid-connect-core-1_0.html#IssuerIdentifier) from the OIDC Identity Provider that will issue JWT access tokens
* `TOKEN_AUDIENCE` (Optional) the Token Audiences as defined in the OIDC identity provider that will issue JWT access tokens
* `TOKEN_CLIENT_ID_CLAIM` (Optional) the name of the claim that will be used to store the client application identifier in the JWT access token (examples `azp` or `client_id`)
* `IDP_APP_CLIENT_ID` (Optional) the Client ID issued by the Identity Provider. This value needs to be imported in Apigee to be able to identify the client app traffic
* `IDP_APP_CLIENT_SECRET` (Optional) the Client Secret issued by the Identity Provider. This value is not used in this sample therefore it can also be an arbitrary value

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources.

```sh
./deploy-authorize-idp-access-tokens.sh
```

This script creates a Shared Flow, an API Proxy, an API product, a sample App developer, an App, and environment properties. The script also imports client application credentials obtained from an identity provider.

### Testing the sample with Google's OAuth Playground

If you didn't set any values for `Optional` environment variables during the setup step, then the deploy script will provide a link to the Google OAuth Playground with custom configuration that will target a mock Authorization Server deployed in the same Apigee environment as the test proxy. To test the sample proxy with a JWT access token, follow the link on a separate browser tab and complete the steps below:

1. After landing on the Google OAuth Playground, accept the use of a custom OAuth configuration by clicking the green "OK! That's fine." button in the warning popup.

2. On the left panel there's a 3-step wizard to obtain access tokens from a mock authorization server. At the bottom section of Step 1 "Select & authorize APIs", input any, some, or all of the allowed scopes (comma separated if more than one) and press the Authorize APIs button. The allowed scopes are `READ`, `WRITE`, and `ACTION`.

3. On Step 2 "Exchange authorization code for tokens", press the blue "Exchange authorization code for tokens" button. On the "Request / Response" section at the center of the screen you'll be able to retrieve the value of the JWT access token issued by the mock authorization server. You can copy this value to inspect it further using the JWT debugger tool at [JWT.io](https://jwt.io/).

4. On Step 4 "Configure request to API", copy the sample request URI provided by the deploy script output and paste it in the Request URI value of the wizard and leave the rest of  settings with default values. Finally, press the blue "Send the request" button to send a request to the sample proxy that will verify the JWT access token issued by the mock authorization server.

### Testing the sample with your own OIDC Identity Provider

If you set `Optional` environment variables with values from your own OIDC Identity Provider during the setup step, then obtain a JWT access token by completing an authorization flow of your choice. Set the JWT access token as a value of the `IDP_TOKEN` environment variable and send a cURL request as shown below:

> _Note: Use the same Client ID / App Key and Secret used in the environment variables file._

```bash
IDP_TOKEN=REPLACE_WITH_IDP_ACCESS_TOKEN
curl -v https://$APIGEE_HOST/v1/samples/authorize-idp-access-tokens -H "Authorization: Bearer $IDP_TOKEN"
```

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully authorized in Apigee an access token issued by an Identity Provider.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to delete the artifacts from this example from your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-authorize-idp-access-tokens.sh
```
