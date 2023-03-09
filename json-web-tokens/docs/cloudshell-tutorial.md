# JSON Web Tokens

---
This sample shows how to generate and validate JSON Web Tokens (JWT) using Apigee's [JWT policies](https://cloud.google.com/apigee/docs/api-platform/reference/policies/jwt-policies-overview). 

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `json-web-tokens` directory in the Cloud shell.

```sh
cd json-web-tokens
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="json-web-tokens/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources necessary to test the JWT policies.

```sh
./deploy-jwt.sh
```

This script creates a sample API Proxy and a key value map containing a public/private keypair. The script also tests that the deployment and configuration has been sucessful.


### Test the APIs

The script that deploys the Apigee API proxies prints the information you will need to run the commands below.

Set the proxy URL:
```sh
export PROXY_URL=<replace with script output>
```

First, generate a _digitally signed_ JWT:
```sh
curl -X POST https://$PROXY_URL/v1/samples/json-web-tokens/generate-signed
```

Next, verify the signed token by copying the value of `output_jwt` from the response and paste into the following request:
```sh
curl -X POST https://$PROXY_URL/v1/samples/json-web-tokens/verify-signed \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'JWT=<output_jwt value>'
```

The output should return `JWT OK` followed by the decoded token claims.

Then, generate an _encrypted_ JWT:
```sh
curl -X POST https://$PROXY_URL/v1/samples/json-web-tokens/generate-encrypted
```

Finally, verify the encrypted token by copying the value of `output_jwt` from the response and paste into the following request:
```sh
curl -X POST https://$PROXY_URL/v1/samples/json-web-tokens/verify-encrypted \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'JWT=<output_jwt value>'
```

Once again, the output should return `JWT OK` followed by the decoded token claims, however this time note the [`enc`](https://www.rfc-editor.org/rfc/rfc7516#section-4.1.2) header value is also present in the response.

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented JSON Web Token generation and verification.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-json-web-tokens.sh
```
