# Client credentials grant type

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

## Prerequisites

To run this sample, you'll need:
- [Apigee Organization](https://cloud.google.com/apigee/pricing)


## Dependencies
- [`apigee-sackmesser`](https://github.com/apigee/devrel/tree/main/tools/apigee-sackmesser)
- `npm` and Node.js


## Quick Start
To deploy the artifacts, first appropriately set the following environment variables:
```sh
export APIGEE_X_ORG=
export APIGEE_X_ENV=
export APIGEE_X_HOSTNAME=
export APIGEE_X_TOKEN=$(gcloud auth print-access-token)
```

Then, execute `pipeline.sh`:
```
sh ./pipeline.sh
```
Note that the pipeline will automatically execute integration tests after a successful deployment. To clean up all
artifacts, set the following variable and re-run pipeline.sh:
```
OAUTH_CLIENT_CREDENTIALS_CLEAN_UP=true; sh pipeline.sh
```

## Tests
To run the integration tests, first retrieve Node.js dependencies with:
```
npm install
```
and then:
```
npm run test
```

## Example Requests
For additional examples, including negative test cases,
see the [auth-schemes.feature](./test/integration/features/oauth-client-credentials.feature) file.

### OAuth Bearer Token (RFC 6749)
First obtain a short-lived opaque access token using the token endpoint. Instructions for how to find
application credentials can be found [here](https://cloud.google.com/apigee/docs/api-platform/publish/creating-apps-surface-your-api#view-api-key).
If the pipeline has been successfully executed, you will see the apigee-samples-app created for testing purposes.
```
curl -v -XPOST https://$APIGEE_X_HOSTNAME/apigee-samples/oauth-client-credentials/token -u $CLIENT_ID:$CLIENT_SECRET -d "grant_type=client_credentials"
```
> _Note: Under normal circumstances, avoid providing secrets on the command itself using `-u`_

Copy the value of the `access_token` property from the response body of the previous request and include it in the following request:
```
curl -v https://$APIGEE_X_HOSTNAME/apigee-samples/oauth-client-credentials/resource -H "Authorization: Bearer $TOKEN"