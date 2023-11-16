# Data De-Identification in Apigee

This sample shows how to use the ["Data De-Identification"
capability](https://cloud.google.com/dlp/docs/deidentify-sensitive-data) within
the Sensitive Data Protection service in Google Cloud, to mask data, from within
an Apigee API Proxy.

> As of mid-2023, Cloud Data Loss Prevention (Cloud DLP) is now a part of
Sensitive Data Protection. The API name remains the same: Cloud Data Loss
Prevention API (DLP API). For information about the services that make up
Sensitive Data Protection, see Sensitive Data Protection overview.

## About Data De-Identification

De-identification is the process of removing identifying information from
data. The DLP API in Google Cloud detects sensitive data such as personally
identifiable information (PII) like email addresses or phone numbers, and then
uses a de-identification transformation to mask, delete, or otherwise obscure
the data.

For example, you can mask sensitive data by partially or fully replacing
characters with a symbol, such as an asterisk (*) or hash (#). Or you can
replace each instance of sensitive data with a surrogate string. You can even
replace sensitive data with an encrypted form.

Learn more in [this video](https://youtu.be/JLDpbXbT6wo).

### An Example

Suppose you have an inbound XML document, like this:

```xml
<ServiceRequest xmlns='urn:932F4698-0A64-49D4-963F-E6615BC399E8'>
  <CustomerId>C939D5E8-2FEB-477E-A9B8-E87371973E61</CustomerId>
  <URL>https://marcia.com</URL>
  <Email>marcia@example.com</Email>
  <Phone>434-902-1092</Phone>
  <Requested>2023-11-15T21:36:06.391Z</Requested>
</ServiceRequest>
```

You might like to mask the URL, Email, and Phone, resulting in something like this:

```xml
<ServiceRequest xmlns='urn:932F4698-0A64-49D4-963F-E6615BC399E8'>
  <CustomerId>C939D5E8-2FEB-477E-A9B8-E87371973E61</CustomerId>
  <URL>https://**********</URL>
  <Email>******@*******.com</Email>
  <Phone>***-***-**92</Phone>
  <Requested>2023-11-15T21:36:06.391Z</Requested>
</ServiceRequest>
```

Or, you might have a JSON document with sensitive data:

```json
{
  "customerId" : "C939D5E8-2FEB-477E-A9B8-E87371973E61",
  "url": "https://marcia.com",
  "email": "marcia@example.com",
  "phone": "434-902-1092",
  "requested": "2023-11-15T21:36:06.391Z"
}
```

And you want to mask it into this form:

```json
{
  "customerId" : "C939D5E8-2FEB-477E-A9B8-E87371973E61",
  "url": "https://**********",
  "email": "******@*******.com",
  "phone": "***-***-**92",
  "requested": "2023-11-15T21:36:06.391Z"
}
```

Masking allows you to transmit or store the masked data without worry of leaking
information or propagating sensitive data unnecessarily.

## Integrating DLP into an Apigee API Proxy

The DLP service in Google Cloud is accessible via an API endpoint, at
<https://dlp.googleapis.com> .

Apigee proxies can perform a series of steps on an inbound API request; usually
that includes verifying some credential like an API Key or a Token, and maybe
enforcing other constraints. Masking data with DLP can be just one additional
step that an API Proxy can perform.

The DLP API can accept inbound HTTP POST requests, formatted in JSON, and can return masked data.
Apigee can send out the appropriate request via an appropriately configured [ServiceCallout policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/service-callout-policy), and then receive and parse the response.

## Implementation in the API Proxy

This sample uses a simple API Proxy to demonstrate this function. The proxy uses
ServiceCallout to invoke the DLP API, and retrieve the response. The
ServiceCallout policy is configured to automatically generate and attach an
access token, to authenticate to the DLP API.

After receiving the DLP response, the proxy uses an [AssignMessage
policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/assign-message-policy)
to extract the masked data into a context variable. The sample then just sends
back the masked data.  It's a loopback proxy, it does not connect to any remote
service.

For the purposes of the demonstration, this API Proxy is simple. It does not perform authentication of the request via [VerifyAPIKey](https://cloud.google.com/apigee/docs/api-platform/reference/policies/verify-api-key-policy) or [OAuthV2/VerifyAccessToken](https://cloud.google.com/apigee/docs/api-platform/reference/policies/oauthv2-policy#verifyaccesstoken), or any other authentication of the client app or caller. In a real API proxy, you will use other policies, and you'd probably connect to a remote target. This is just a sample.

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)

2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance

3. Permissions to enable the Google Cloud APIs for IAM and DLP

4. Permissions to create and deploy proxies in Apigee. Get these permissions via the Apigee orgadmin role, or the combination of two roles: API Admin and Developer Admin. ([more on Apigee-specific roles](https://cloud.google.com/apigee/docs/api-platform/system-administration/apigee-roles#apigee-specific-roles))

5. Permissions to create service accounts and add roles to a service account.

6. Make sure the following tools are available in your terminal's $PATH. Google
   Cloud Shell has all of these preconfigured.

    - [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    - unzip
    - curl
    - jq
    - npm

## CloudShell Tutorial

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=data-deidentification/docs/cloudshell-tutorial.md)

## Manual Setup instructions

If you've clicked the blue button above, you can ignore the rest of this README!
If you choose _not_ to follow the tutorial in Cloud Shell, you can follow these steps on your own:

1. First, lets enable the required APIs

```sh
gcloud services enable iam.googleapis.com dlp.googleapis.com
```

1. Clone the `apigee-samples` repo, and cd into the `data-deidentification` directory

   ```bash
   git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
   cd data-deidentification
   ```

2. Edit `env.sh` and configure the following variables:

   - `PROJECT` the project where your Apigee organization is located
   - `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
   - `APIGEE_ENV` the Apigee environment where the demo resources should be created

   Now source the `env.sh` file

   ```bash
   source ./env.sh
   ```

3. Configure the API proxy, the de-identification templates in DLP, and a
   service account to allow Apigee to connect to DLP securely.

   ```bash
   ./setup-data-deidentification.sh
   ```

   This step will also run some tests to verify the setup.
   It will then print some information about the setup.

   What is a de-identification template?? [The documentation](
   https://cloud.google.com/dlp/docs/concepts-templates) states:

   > Templates are useful for decoupling configuration information such as what you inspect for and how you de-identify it from the implementation of your requests.

   NB: A de-identification template is configuration in DLP, telling it what
   kinds of information to de-identify, and how. This sample sets up two
   different templates: one that will mask URLs, phone, and email, with
   different masking for each one (for example don't mask @ or dot in email
   addresses, don't mask dot or dash in phone numbers...), and a second template
   that masks only email addresses.

### Running the automated tests

Ensure the required environment variables have been set correctly. The setup
script will provide easy cut/paste instructions regarding the variables and the values to set.

And then use `npm` to run the tests:

```bash
npm run test
```

### Manually send requests

To manually test the proxy, you can send in XML and JSON with curl.

Try XML first:

```bash
curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-xml \
      -H content-type:application/xml -d @example-input.xml
```

This will show you the masked XML as well as the original XML in output.

Try a JSON payload:

```bash
curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-json \
      -H content-type:application/json -d @example-input.json
```

Similar to the above, this will show you the masked and original JSON.

You can send any json or XML you like.

```bash
curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-json \
  -H content-type:application/json \
  -d '{ "contact": { "phn": "412-563-7724", "email": "nate@cymbalgroup.com" } }'

curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-xml \
  -H content-type:application/xml \
  -d '<root><addr>me@cymbalgroup.net</addr><phn>412-503-7724</phn></root>'

```

If you want to mask just Email addresses, you can pass a query parameter to instruct the API
proxy to use a different DLP template:

```bash
curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-json?justemail=true \
  -H content-type:application/json \
  -d '{ "contact": { "phn": "412-563-7724", "email": "nate@cymbalgroup.com" } }'
```

This sample uses two different DLP de-identification templates. Compare the results you see when using the query parameter, to the results you see without the query parameter:

```bash
curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-json \
  -H content-type:application/json \
  -d '{ "contact": { "phn": "412-563-7724", "email": "nate@cymbalgroup.com" } }'
```

When you use DLP in your systems, you can define the templates that make sense
for you.

You can crack open the setup script to see how to define your own
templates. Experiment with other templates if you like.

## Modifying the proxy

If you want to modify the sample proxy, you can do that offline by editing the proxy configuration files.
Then, you can re-import and deploy the modified proxy, with this script:

```bash
./import-and-deploy.sh
```

## Cleanup

To remove the configuration from this example from your GCP project, first
source your `env.sh` script, and then, in your shell, run:

```bash
./clean-apiproduct-operations.sh
```
