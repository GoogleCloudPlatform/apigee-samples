# API Product Operations

---

This sample shows how to use API Product Operations to limit the particular
verb/path combinations that will be permitted for an authenticated caller
application.

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `apiproduct-operations` directory in the Cloud shell.

```sh
cd apiproduct-operations
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="apiproduct-operations/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources necessary to test the quota policy.

```sh
./setup-apiproduct-operations.sh
```

This script imports a sample API Proxy from the filesystem, and then deploys it.
It then creates a Developer entity, three API products with different Operations
settings, and three Apps, each one authorized for just one of those products.

The script also tests that the deployment and configuration has been sucessful.

---

## Test the APIs using API Key Verification

The script that deploys the Apigee API proxies prints the proxy and app
information you will need to run the commands below.

1. First, set the required shell variables:
   ```sh
   export SAMPLE_PROXY_BASEPATH=<replace with script output>
   export VIEWER_CLIENT_ID=<replace with script output>
   export CREATOR_CLIENT_ID=<replace with script output>
   export ADMIN_CLIENT_ID=<replace with script output>
   ```

2. Now, run the following command, intended to be the kind of REST request an
   app might send to list items in a collection:

   ```sh
   curl -i -X GET https://${APIGEE_HOST}/v1/samples/apiproduct-operations/apikey/users \
      -H APIKEY:$VIEWER_CLIENT_ID
   ```

   This request uses the API Key authorized for the VIEWER product. You should see
   a 200 response.  This API does not actually return a list of users; it's
   returning a status of the credential check.  Observe the success response; it
   will show the the name of the API Product, the path of the authorized resource,
   and the verb used.


3. Now, run the same request but with a different key, the one for the CREATOR:
   ```sh
   curl -i -X GET https://${APIGEE_HOST}/v1/samples/apiproduct-operations/apikey/users \
      -H APIKEY:$CREATOR_CLIENT_ID
   ```

   You should now see a rejection response, with a status of 401 Unauthorized,
   indicating that when an app uses the credential authorized for the CREATOR
   Product to request a list of users, Apigee rejects the request.

4. Now try a creation request. This is intended to be the kind of REST request an
   app might send to create a new item within a collection:
   ```sh
   curl -i -X POST -d '' https://${APIGEE_HOST}/v1/samples/apiproduct-operations/apikey/users \
      -H APIKEY:$VIEWER_CLIENT_ID
   ```

   This request uses the credential that is authorized for the VIEWER product.

   You should again see a rejection response.  When an app uses the credential
   authorized for the VIEWER Product to request creation of a new user, Apigee
   rejects the request.

5. Conversely, when you use the CREATOR credential for that kind of request, Apigee allows the request:
   ```sh
   curl -i -X POST -d '' https://${APIGEE_HOST}/v1/samples/apiproduct-operations/apikey/users \
      -H APIKEY:$CREATOR_CLIENT_ID
   ```

6. But when you use the CREATOR credential to request a DELETE on a specific user, Apigee rejects the request:
   ```sh
   curl -i -X DELETE https://${APIGEE_HOST}/v1/samples/apiproduct-operations/apikey/users/1234 \
      -H APIKEY:$CREATOR_CLIENT_ID
   ```
   This is as expected; the CREATOR product does not grant authorization on `DELETE /apikey/users/1234`.

7. The set of operations on an API Product need not be grouped by verb.  A
   single API Product might be authorized for any set of verb+path combinations.

   For example, the ADMIN product is configured to allow GET, POST, or DELETE requests in that API Proxy. Using the ADMIN credential, all of the following should succeed:
   ```sh
   curl -i -X GET https://${APIGEE_HOST}/v1/samples/apiproduct-operations/apikey/users \
      -H APIKEY:$ADMIN_CLIENT_ID
   curl -i -X POST -d '' https://${APIGEE_HOST}/v1/samples/apiproduct-operations/apikey/users \
      -H APIKEY:$ADMIN_CLIENT_ID
   curl -i -X DELETE https://${APIGEE_HOST}/v1/samples/apiproduct-operations/apikey/users/1234 \
      -H APIKEY:$ADMIN_CLIENT_ID
   ```

---

## Optional: Test the APIs using OAuthV2 token Validation

The above steps describe how to use an API Key as the credential.
Apigee performs the same checks when you configure your API Proxy to verify an OAuthV2 Bearer token.

To try that out, you will need to first obtain a valid token, and then pass it
in the same requests as shown above, just modifying the `apikey` path element to
be `token`, and passing a different header.


0. First, make sure that you have set the X_CLIENT_SECRET shell variables required for obtaining tokens:
   ```sh
   export VIEWER_CLIENT_SECRET=<replace with script output>
   export CREATOR_CLIENT_SECRET=<replace with script output>
   export ADMIN_CLIENT_SECRET=<replace with script output>
   ```

1. Now, run the following command, to obtain a token for the VIEWER.
   ```sh
   curl -i -X POST https://${APIGEE_HOST}/v1/samples/apiproduct-operations-oauth2-cc/token \
       -u $VIEWER_CLIENT_ID:$VIEWER_CLIENT_SECRET -d 'grant_type=client_credentials'
   ```
   You should see an access token in the response:
   ```json
   {
     "token_type": "Bearer",
     "access_token": "dIrPeAlpORyrZCurH1CdY9brICcO",
     "grant_type": "client_credentials",
     "issued_at": 1687997951,
     "expires_in": 1799
   }
   ```
   Set a shell variable containing that access token:
   ```sh
   VIEWER_ACCESS_TOKEN=<replace with the token in your curl output>
   ```

2. Invoke the /users API using the viewer token:
   ```sh
   curl -i -X GET https://${APIGEE_HOST}/v1/samples/apiproduct-operations/token/users \
      -H TOKEN:$VIEWER_ACCESS_TOKEN
   ```

3. Now obtain a token for the creator.
   ```sh
   curl -i -X POST https://${APIGEE_HOST}/v1/samples/apiproduct-operations-oauth2-cc/token \
       -u $CREATOR_CLIENT_ID:$CREATOR_CLIENT_SECRET -d 'grant_type=client_credentials'
   ```
   and set the shell variable with the token shown in the response:
   ```sh
   CREATOR_ACCESS_TOKEN=<replace with token from curl output>
   ```

4. Use the creator token to invoke the /users API :
   ```sh
   curl -i -X GET https://${APIGEE_HOST}/v1/samples/apiproduct-operations/token/users \
      -H TOKEN:$CREATOR_ACCESS_TOKEN
   ```

   You should see this final request be rejected with a 401 status. This is
   expected, because the creator product does not grant authorization for the
   `GET /*/users` operation.

5. Now try a creation request, using the viewer token:
   ```sh
   curl -i -X POST -d '' https://${APIGEE_HOST}/v1/samples/apiproduct-operations/token/users \
      -H TOKEN:$VIEWER_ACCESS_TOKEN
   ```

   This request uses the credential that is authorized for the VIEWER product.

   You should again see a rejection response. When an app uses the credential
   authorized for the VIEWER Product to request creation of a new user, Apigee
   rejects the request. This is true whether the credential is an API Key or an
   Access Token.

6. Conversely, when you use the CREATOR credential for that kind of request, Apigee allows the request:
   ```sh
   curl -i -X POST -d '' https://${APIGEE_HOST}/v1/samples/apiproduct-operations/token/users \
      -H TOKEN:$CREATOR_ACCESS_TOKEN
   ```
   Again, as expected.

7. Obtain a token for the admin:
   ```sh
   curl -i -X POST https://${APIGEE_HOST}/v1/samples/apiproduct-operations-oauth2-cc/token \
       -u $ADMIN_CLIENT_ID:$ADMIN_CLIENT_SECRET -d 'grant_type=client_credentials'
   ```
   and again, set the shell variable with the token shown in the response:
   ```sh
   ADMIN_ACCESS_TOKEN=<replace with token from curl output>
   ```

8. Use it to invoke any API:
   ```sh
   curl -i -X GET https://${APIGEE_HOST}/v1/samples/apiproduct-operations/token/users \
      -H TOKEN:$ADMIN_ACCESS_TOKEN
   curl -i -X POST -d '' https://${APIGEE_HOST}/v1/samples/apiproduct-operations/token/users  \
      -H TOKEN:$ADMIN_ACCESS_TOKEN
   curl -i -X DELETE https://${APIGEE_HOST}/v1/samples/apiproduct-operations/token/users/1234  \
      -H TOKEN:$ADMIN_ACCESS_TOKEN
   ```

   All of these should succeed; the admin product grants authorization for all of those operations.

9. But when you use the creator token to request a DELETE on a specific user:
   ```sh
   curl -i -X DELETE https://${APIGEE_HOST}/v1/samples/apiproduct-operations/token/users/1234 \
      -H TOKEN:$CREATOR_ACCESS_TOKEN
   ```

   ..., Apigee rejects the request. This is as expected; the creator product
   does not grant authorization on `DELETE /token/users/1234`.

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented and tested a set of API Products with different Operations.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee
Organization, first source your `env.sh` script, and then run

```bash
./clean-up-basic-quota.sh
```
