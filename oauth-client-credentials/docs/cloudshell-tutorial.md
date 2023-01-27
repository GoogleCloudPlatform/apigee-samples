# Client Credentials Grant Type

---
This sample lets you request an OAuth token from Apigee using the OAuth 2.0 client credentials grant type flow.

Let's get started!

---

## Setup environment

Navigate to the 'oauth-client-credentials' drirectory in the Cloud shell.

```sh
cd oauth-client-credentials
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="oauth-client-credentials/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```
---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources necessary to request an OAuth token.

```sh
./deploy-oauth-client-credentials.sh
```

This script creates an API Proxy, API product, a sample App developer, and App. The script also tests that the deployment and configuration has been sucessful.


### Test the APIs

The script that deploys the Apigee API proxies prints the proxy and app information you will need to run the commands below.

First obtain a short-lived opaque access token using the token endpoint.

```
curl -v -XPOST https://$APIGEE_HOST/apigee-samples/oauth-client-credentials/token -u $APP_CLIENT_ID:$APP_CLIENT_SECRET -d "grant_type=client_credentials"
```
> _Note: Under normal circumstances, avoid providing secrets on the command itself using `-u`_

Copy the value of the `access_token` property from the response body of the previous request and include it in the following request:
```
curl -v https://$APIGEE_HOST/apigee-samples/oauth-client-credentials/resource -H "Authorization: Bearer access_token"
```

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully requested and used an OAuth token from Apigee using the OAuth 2.0 client credentials grant type flow.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artefacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-oauth-client-credentials.sh
```
