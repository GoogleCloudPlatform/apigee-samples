# Client Credentials Grant Type with Scope

---
This sample lets you request an OAuth token from Apigee using the OAuth 2.0 client credentials grant type flow and limit access using [OAuth2 scopes](https://cloud.google.com/apigee/docs/api-platform/security/oauth/working-scopes).

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'oauth-client-credentials-with-scope' directory in the Cloud shell.

```sh
cd oauth-client-credentials-with-scope
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="oauth-client-credentials-with-scope/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources.

```sh
./deploy-oauth-client-credentials-with-scope.sh
```

This script creates an API Proxy, two API products (one with read scope and the other with read,write scopes), a sample App developer, and App. The script also tests that the deployment and configuration has been successful.

### Test the APIs

The script that deploys the Apigee resources will print two sets of cURL commands.

The first set returns a token with `read` access. You will find that it only works with the GET call. The POST call will fail. This is because of the insufficient scope to make a POST call to that resource.

Similarly, the second set of cURL commands include a token with `write` access. With this token, both of the cURL commands should return a successful response.

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully requested and used an OAuth token from Apigee using the OAuth 2.0 client credentials grant type flow and limited the access using OAuth2 scopes.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-oauth-client-credentials-with-scope.sh
```
