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
cd apigee-samples/authorize-idp-access-tokens
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="authorize-idp-access-tokens/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

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


### Test the APIs

Obtain a JWT access token from the Identity Provider. The grant type and method to obain the access token is specific to each IdP. However, it is common for Identity Providers to support the client_credentials grant type to issue access tokens to authorized applications.

> _Note: Use the same Client ID / App Key and Secret used in the environment variables file._

Include the obtained access token in the following request:
```
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
