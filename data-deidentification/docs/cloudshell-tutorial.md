# Data Masking in Apigee via the DLP API

This sample shows how to use DLP Data De-Identification to mask
sensitive data within an Apigee API Proxy.

Let's get started!

---

## Set up your environment

The following steps will set up your environment.

## First, sign-in

1. Check your credentials.

   ```sh
   gcloud auth print-access-token
   ```

   If you see a token, then you're authenticated.

   If you do not see a token, then
   gcloud will advise you to login. Do so:

   ```sh
   gcloud auth login
   ```

   When you do that, you _may_ see a warning, telling you:

   > You are already authenticated with gcloud when running
   > inside the Cloud Shell and so do not need to run this
   > command. Do you wish to proceed anyway?

   Ignore that :). Proceed anyway.

---

## Change to the correct directory, and set some variables

2. Navigate to the `data-deidentification` directory in the Cloud shell.

   ```sh
   cd data-deidentification
   ```

   Edit the provided sample `env.sh` file, and set the environment variables there.

   Click <walkthrough-editor-open-file
   filePath="data-deidentification/env.sh">here</walkthrough-editor-open-file>
   to open the file in the editor

   Then, save your changes, and source the `env.sh` file in the Cloud Shell.

   ```sh
   source ./env.sh
   ```

---

## Provision the assets for Apigee and DLP

Next, let's create and deploy the resources necessary to run the data deidentification sample.

```sh
./setup-data-deidentification.sh
```

This script creates and provisions the necessary assets in your Google Cloud
project to run the sample.  It creates two different de-identification
templates, creates a Service Account and applies the necessary permissions to
that service account, configures the sample API Proxy stored in the filesystem
with the names of the de-identification templates, runs apigeelint on the proxy,
then imports and deploys it.

The script also tests that the deployment and configuration has been successful.

But what is a de-identification template?

[The documentation](https://cloud.google.com/dlp/docs/concepts-templates) states:

> Templates are useful for decoupling configuration information such as what you inspect for and how you de-identify it from the implementation of your requests.

A de-identification template is configuration in DLP, telling it what
kinds of information to de-identify, and how. This sample sets up two
different templates: one that will mask URLs, phone, and email, with
different masking for each one (for example don't mask @ or dot in email
addresses, don't mask dot or dash in phone numbers...), and a second template
that masks only email addresses.

---

## Run the basic test for the APIs

When the script finishes, it prints the proxy and app
information you will need to run the commands below.

1. To run the bundled tests, you need to set the required shell variable:

   ```sh
   export SAMPLE_PROXY_BASEPATH=/v1/samples/data-deidentification
   ```

2. Then run the tests:

   ```sh
   npm run test
   ```

## Test the APIs for masking XML

3. You can also run your own tests, manually. Run the following command,
   to send XML into the proxy to be masked.

   ```sh
   curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-xml \
      -H content-type:application/xml -d @example-input.xml
   ```

   This request sends in the contents of an XML file as a payload.
   The proxy will send that payload to DLP, and then capture the masked response.
   The proxy sends back a response with the original XML and the masked version,
   to allow you to compare and see the results.

4. To mask that same payload with a different de-identification template,
   use the `justemail=true` query parameter:

   ```sh
   curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-xml?justemail=true \
      -H content-type:application/xml -d @example-input.xml
   ```

   You can see the result of this request masks only the email address.
   This is because the DLP de-identification template used in this case,
   is configured to mask only email addresses. When you use DLP in your systems,
   you can define the templates that make sense for you.

5. You can send any XML you like into the proxy. DLP will interpret the XML
   and mask appropriately. Try different forms, like this:

   ```sh
   curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-xml \
      -H content-type:application/xml -d '<root><addr>me@cymbalgroup.net</addr></root>'
   ```

## Test the APIs for masking JSON

6. The proxy can also mask JSON.

   ```sh
   curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-json \
      -H content-type:application/json -d @example-input.json
   ```

   This request sends in the contents of a JSON file as a payload.
   The proxy will send that payload to DLP, and then capture the masked response.
   The proxy sends back a response with the original JSON and the masked version.
   You can see that the URL, Email, and Phone number have been masked.

7. To mask that same payload with a different de-identification template,
   again, use the `justemail=true` query parameter:

   ```sh
   curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-json?justemail=true \
      -H content-type:application/json -d @example-input.json
   ```

   As with the XML version, you can see the result of this request masks only the email address.

8. You can send any JSON you like into the proxy. DLP will mask appropriately. Try different forms, like this:

   ```sh
   curl -i -X POST https://${APIGEE_HOST}/v1/samples/data-deidentification/mask-json \
      -H content-type:application/json \
      -d '{ "contact": { "phn": "412-563-7724", "email": "nate@cymbalgroup.com" } }'
   ```

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully configured an Apigee proxy to call out to DLP to de-identify data.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee
Organization, first source your `env.sh` script, and then run:

```bash
./clean-data-deidentification.sh
```
