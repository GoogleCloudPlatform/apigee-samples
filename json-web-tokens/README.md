# JSON Web Tokens

This sample shows how to generate and validate JSON Web Tokens (JWT) using Apigee's [JWT policies](https://cloud.google.com/apigee/docs/api-platform/reference/policies/jwt-policies-overview).

## About JWTs

JSON Web Token (JWT for short) is a commonly used mechanism to share sets of claims or assertions between connected applications. Claims in a JWT are encoded as a JSON object, which may be digitally signed and/or encrypted. JWTs are often used to transfer information about application or user identity, and are utilized by protocols such as OAuth 2.0 and OpenID Connect. The JWT specification is described by [RFC 7519](https://www.rfc-editor.org/rfc/rfc7519). JWTs are part of a family of related specifications including JSON Web Signature (JWS), JSON Web Encryption (JWE) plus others. For an introduction to JWTs see the guide [here](https://jwt.io/introduction).   Apigee offers out of the box policies to generate, verify, and decode both JWT and JWS payloads.

## How it works

Customers can use Apigee's JWT policies to:

* [Generate](https://cloud.google.com/apigee/docs/api-platform/reference/policies/generate-jwt-policy) a new JWT on either the proxy or target endpoint sides of an Apigee proxy. For example, you might create a proxy request flow that generates a JWT and returns it to a client. Or, you might design a proxy so that it generates a JWT on the target request flow, and attaches it to the request sent to the target. The claims in the JWT would then be available to backend services to apply further security processing.
* [Verify](https://cloud.google.com/apigee/docs/api-platform/reference/policies/verify-jwt-policy) and extract claims from a JWT obtained from inbound client requests, from target service responses, from [ServiceCallout](https://cloud.google.com/apigee/docs/api-platform/reference/policies/service-callout-policy) policy responses, or from other sources. Apigee can verify the signature on a JWT, regardless of where it was generated, using either RSA or HMAC algorithms.
* [Decode](https://cloud.google.com/apigee/docs/api-platform/reference/policies/decode-jwt-policy) a JWT. Decoding is most useful when used in concert with the VerifyJWT policy, when the value of a claim or header from within the JWT must be known before verifying the token.

Apigee supports generation and verification of both digitally signed and encrypted JWTs. For more detailed information on how Apigee's policies can be used along with information on supported algorithms, see the [JWS and JWT policies overview](https://cloud.google.com/apigee/docs/api-platform/reference/policies/jwt-policies-overview) page.

## Implementation on Apigee

This sample proxy exposes several endpoints:
* `/v1/samples/json-web-tokens/generate-signed` generates a digitally signed JWT using the private key generated during the sample setup, and returns the token in the response payload and a header
* `/v1/samples/json-web-tokens/generate-encrypted` generates an encrypted JWT using the public key generated during the sample setup, and returns the token in the response payload and a header
* `/v1/samples/json-web-tokens/verify-signed` accepts a digitally signed JWT as a form parameter, verifies the token signature against the public key, checks that the [`Subject`](https://www.rfc-editor.org/rfc/rfc7519#section-4.1.2) and [`Audience`](https://www.rfc-editor.org/rfc/rfc7519#section-4.1.3) claims match allowed values, then decodes and outputs the token contents to the response in plain text.
* `/v1/samples/json-web-tokens/verify-encrypted` accepts an encrypted JWT as a form parameter, decrypts the token using the private key, checks that the [`Subject`](https://www.rfc-editor.org/rfc/rfc7519#section-4.1.2) and [`Audience`](https://www.rfc-editor.org/rfc/rfc7519#section-4.1.3) claims match allowed values, then decodes and outputs the token contents to the response in plain text
* `/v1/samples/json-web-tokens/private-key` outputs the X.509 private key
* `/v1/samples/json-web-tokens/public-key` outputs the X.509 public key

The keypair is stored in an encrypted [key value map](https://cloud.google.com/apigee/docs/api-platform/cache/key-value-maps) named `jwt-keys` and the keys are retrieved using a [KeyValueMapOperations](https://cloud.google.com/apigee/docs/api-platform/reference/policies/key-value-map-operations-policy) policy. Note that Apigee also supports [using a JWKS endpoint](https://cloud.google.com/apigee/docs/api-platform/reference/policies/jwt-policies-overview#usingajsonwebkeysetjwkstoverifyajwt) to specify keys for signature verification, but that is beyond the scope of this sample.

The verification policies in this sample also show how to use the [TimeAllowance](https://cloud.google.com/apigee/docs/api-platform/reference/policies/verify-jwt-policy#timeallowance) element to allow a "grace period" (30 seconds in this sample) for the [Expiration Time](https://www.rfc-editor.org/rfc/rfc7519#section-4.1.4) and [Not Before](https://www.rfc-editor.org/rfc/rfc7519#section-4.1.5) claims, which can be useful in the case of errors caused by clock skew between the issuer and verifier.

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Access to deploy proxies and create KVMs in Apigee
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * openssl
    * npm

# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=json-web-tokens/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the `apigee-samples` repo, and switch the `json-web-tokens` directory


```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/json-web-tokens
```

2. Edit `env.sh` and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee API proxies, products and apps

```bash
./deploy-jwt.sh
```

## Testing the JWT Proxy

To run the tests, first retrieve Node.js dependencies with:
```
npm install
```
Ensure the following environment variables have been set correctly:
* `PROXY_URL`

and then run the tests:
```
npm run test
```

## Example Requests

To generate a signed JWT:
```
curl -X POST https://$APIGEE_HOST/v1/samples/json-web-tokens/generate-signed
```

You should see an response like this:
```
{
    "output_jwt": "<JWT value>"
}
```

To verify, copy the value from the output above and paste into the following request:
```
curl -X POST https://$APIGEE_HOST/v1/samples/json-web-tokens/verify-signed \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'JWT=<output_jwt value>'
```

The output should return `JWT OK` followed by the decoded token claims.

To generate an encrypted JWT:
```
curl -X POST https://$APIGEE_HOST/v1/samples/json-web-tokens/generate-encrypted
```

To verify, copy the value from the output above and paste into the following request:
```
curl -X POST https://$APIGEE_HOST/v1/samples/json-web-tokens/verify-encrypted \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'JWT=<output_jwt value>'
```
Note the [`enc`](https://www.rfc-editor.org/rfc/rfc7516#section-4.1.2) header is returned in the response for the encrypted token.

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-jwt.sh
```