# llm-vertexai-agent

---

This is a sample on how to deploy a sample Apigee proxy and configure it as a tool in [Conversational Agents](https://cloud.google.com/dialogflow/cx/docs). 

## Pre-Requisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Enable Vertex AI in your project

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'llm-vertexai-agent' directory in the Cloud shell.

```sh
cd llm-vertexai-agent
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="llm-vertexai-agent/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee configurations

Next, let's deploy the sample to Apigee. Just run

```bash
./deploy-llm-vertexai-agent.sh
```
---

## Verification

Run this curl command

```sh
curl --location "https://$APIGEE_HOST/v1/samples/llm-vertexai-agent/products -H "Content-Type: application/json" -H "x-apikey: $APIKEY" 
```

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed Apigee proxy that can be configured as a Tool in Conversational Agents

You can now go back to the [notebook](https://github.com/GoogleCloudPlatform/apigee-samples/blob/main/llm-vertexai-agent/llm_vertexai_agent.ipynb) to test the sample.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-llm-vertexai-agent.sh
```
