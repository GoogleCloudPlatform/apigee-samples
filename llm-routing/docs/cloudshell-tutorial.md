# llm-routing

---

This is a sample Apigee proxy to demonstrate the routing capabilities of Apigee across different LLM providers. In this sample we will use Google VertexAI, Mistral and HuggingFace as the LLM providers

## Pre-Requisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Enable Vertex AI in your project
4. Create a [HuggingFace Account](https://huggingface.co/) and create an Access Token. When [creating](https://huggingface.co/docs/hub/en/security-tokens) the token choose 'Read' for the token type.
5. Similar to HuggingFace, create a [Mistral Account](https://console.mistral.ai/) and create an API Key
6. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    - [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    - [apigeecli](https://github.com/apigee/apigeecli)
    - unzip
    - curl
    - jq

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'llm-routing' directory in the Cloud shell.

```sh
cd llm-routing
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="llm-routing/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee configurations

Next, let's deploy the sample to Apigee. Just run

```bash
./deploy-llm-routing.sh
```

Export the `APIKEY` variable as mentioned in the command output

---

## Verification

You can test the sample with the following curl commands:

### To Gemini

Provide your Provide and Model names in the follow variables:

Run this curl command

```sh
curl --location "https://$APIGEE_HOST/v1/samples/llm-routing/chat/completions" \
--header "Content-Type: application/json" \
--header "x-llm-provider: google" \
--header "x-logpayload: false" \
--header "x-apikey: $APIKEY" \
--data '{"model": "google/gemini-1.5-flash","messages": [{"role": "user","content": [{"type": "image_url","image_url": {"url": "gs://generativeai-downloads/images/character.jpg"}},{"type": "text","text": "Describe this image in one sentence."}]}],"max_tokens": 250,"stream": false}'
```

### To Mistral

Execute the following curl command

```sh
curl --location "https://$APIGEE_HOST/v1/samples/llm-routing/chat/completions" \
--header "Content-Type: application/json" \
--header "x-llm-provider: mistral" \
--header "x-logpayload: false" \
--header "x-apikey: $APIKEY" \
--data '{"model": "open-mistral-nemo","messages": [{"role": "user","content": [{"type": "text","text": "Suggest few names for a flower shop"}]}],"max_tokens": 250,"stream": false}'
```

### To HuggingFace

Execute the following curl command

```sh
curl --location "https://$APIGEE_HOST/v1/samples/llm-routing/chat/completions" \
--header "Content-Type: application/json" \
--header "x-llm-provider: huggingface" \
--header "x-logpayload: false" \
--header "x-apikey: $APIKEY" \
--data '{"model": "meta-llama/Llama-3.2-11B-Vision-Instruct","messages": [{"role": "user","content": [{"type": "text","text": "Suggest few names for a flower shop"}]}],"max_tokens": 250,"stream": false}'
```

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed Apigee proxy to route calls to different LLM providers

You can now go back to the [notebook](https://github.com/GoogleCloudPlatform/apigee-samples/blob/main/llm-routing/llm_routing_v1.ipynb) to test the sample.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-llm-routing.sh
```
