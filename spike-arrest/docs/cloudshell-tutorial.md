# Spike Arrest

---
This sample shows how to protect against traffic spikes using Apigee's [SpikeArrest](https://cloud.google.com/apigee/docs/api-platform/reference/policies/spike-arrest-policy) policy.

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `spike-arrest` directory in the Cloud shell.

```sh
cd spike-arrest
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="spike-arrest/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources necessary to test the spike arrest policy.

```sh
./deploy-spike-arrest.sh
```

This script creates a sample API Proxy and tests that the deployment and configuration has been successful.

### Test the APIs

The script that deploys the Apigee API proxy prints the proxy URL you will need to run the commands below.

Set the proxy URL:

```sh
export PROXY_URL=$APIGEE_HOST/v1/samples/spike-arrest
```

Now let's test the spike arrest by making rapid requests:

```sh
for i in {1..15}; do curl -v https://$PROXY_URL; sleep 0.5; done
```

You should see some requests succeed (200 OK) and others fail with 429 (Too Many Requests) when the rate limit is exceeded.

---

## Understanding Spike Arrest

The spike arrest policy is configured with a rate of 10 requests per minute (10pm). This means:

* Requests are smoothed to allow 1 request every 6 seconds (60 seconds / 10)
* If you send requests faster than this rate, you'll hit the spike arrest limit
* The policy protects your backend from sudden traffic spikes

Try different request patterns:

Fast requests (will trigger spike arrest):
```sh
for i in {1..15}; do curl https://$PROXY_URL; done
```

Slower requests (within the limit):
```sh
for i in {1..10}; do curl https://$PROXY_URL; sleep 7; done
```

---

## Congratulations

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed and tested a spike arrest policy in Apigee.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-spike-arrest.sh
```
