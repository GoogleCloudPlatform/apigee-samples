# llm-routing

---

This is a sample Apigee proxy to demonstrate the routing capabilities of Apigee
across different LLM providers. In this sample we will use Google VertexAI,
Mistral and HuggingFace as the LLM providers.

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

Here are the steps we'll be going through:

1. Ensure that Vertex AI is enabled in your Google Cloud project.
3. Provision all the Apigee artifacts - proxy, KVM, product, developer, app, credential.
4. Invoke the APIs.

Let's get started!

---

## Authenticate to Google Cloud

Ensure you have an active Google Cloud account selected in the Cloud shell. Follow the prompts to authenticate.

```sh
gcloud auth login
```

You may see a prompt: _You are already authenticated with gcloud ..._  Proceed anyway.

---

## Set your environment

Navigate to the 'llm-security-v2' directory in the Cloud shell.

```sh
cd llm-routing
```

In that directory, edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="llm-routing/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

**PLEASE NOTE:**

 - The env.sh file has a setting for the `VERTEXAI_REGION`.  Vertex AI is not
   available in all regions, and not all Vertex AI capabilities are available in
   all Vertex AI regions. For example, as of this writing, the supported regions
   for the OpenAI-compatible chat completions API are:

   | Geography     | regions                                                                  |
   |---------------|--------------------------------------------------------------------------|
   | United States | us-central1, us-east1, us-east4, us-east5, us-south1, us-west1, us-west4 |
   | Europe        | europe-west1, europe-west4, europe-west9, europe-north1                  |
   | Asia Pacific  | asia-northeast1, asia-southeast1                                         |

   For the latest information, please consult the documentation on [Vertex AI
   locations](https://docs.cloud.google.com/vertex-ai/docs/general/locations#available-regions)




Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Ensure Vertex AI is enabled

This may have been done for you previously, elsewhere.
Check that the service is enabled:

```sh
gcloud services list --enabled --project "$PROJECT_ID" --format="value(name.basename())" | grep aiplatform
```

If the output list does not include `aiplatform.googleapis.com` and if you have
the permissions to enable services in your project, you can enable Vertex AI using
this gcloud command:

```sh
gcloud services enable aiplatform.googleapis.com --project "$PROJECT_ID"
```



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
GEMINI_MODEL=gemini-2.5-flash
curl --location "https://\$APIGEE_HOST/v1/samples/llm-routing/chat/completions" \
--header "Content-Type: application/json" \
--header "x-llm-provider: google" \
--header "x-logpayload: false" \
--header "x-apikey: $APIKEY" \
--data '{"model": "'${GEMINI_MODEL}'"","messages": [{"role": "user","content": [{"type": "image_url","image_url": {"url": "gs://generativeai-downloads/images/character.jpg"}},{"type": "text","text": "Describe this image in one sentence."}]}],"max_tokens": 250,"stream": false}'
```

In this request, you are passing the APIKEY created during setup to the
Apigee-managed endpoint. Apigee is configured to verify this key, then apply a
_different_ credential for the upstream service.

In this request, you are also passing an HTTP Header: `x-llm-provider: google`. Based on this header,
the Apigee proxy is routing the request to the Vertex AI service, using credentials from on the service
account you created during setup. In that sense Apigee is performing routing AND security
mediation.


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


Again here, you are passing the  APIKEY created during setup to the Apigee-managed endpoint. Apigee is
configured to verify this key, then apply a _different_ credential for the upstream service.

In this request, you are also passing an HTTP Header: `x-llm-provider:
mistral`. Based on this header, the Apigee proxy is routing the request to the
Mistral endpoint, using the API Key you created in the Mistral.ai portal.

### To HuggingFace

Execute the following curl command

```sh
curl --location "https://$APIGEE_HOST/v1/samples/llm-routing/chat/completions" \
--header "Content-Type: application/json" \
--header "x-llm-provider: huggingface" \
--header "x-logpayload: false" \
--header "x-apikey: $APIKEY" \
--data '{"model": "Meta-Llama-3.1-8B-Instruct","messages": [{"role": "user","content": [{"type": "text","text": "Suggest few names for a flower shop"}]}],"max_tokens": 250,"stream": false}'
```

Because here the HTTP Header `x-llm-provider` takes the value `huggingface`,
the Apigee proxy is routing the request to the
Hugging Face endpoint, using the  HF Token you created as a prerequisite.

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed Apigee proxy to route calls to different LLM providers

You can now go to the [notebook](https://github.com/GoogleCloudPlatform/apigee-samples/blob/main/llm-routing/llm_routing_v1.ipynb) to test the sample further.

This is an example showing how Apigee can route requests to multiple upstream systems. In this case, the Apigee proxy used
the inbound request header `x-llm-provider` to choose the upstream target. But Apigee can use other data for routing
decisions, including:

- any part of the inbound request, such as headers, query params, url path segments, or payload elements.
- an attribute on the caller's App (or credential), the API Product, or the Developer who owns the registered
- the time of day or day of the week
- a dynamically determined load-factor
- prior token usage or consumption
- a weighted random selection for A/B testing
- some combination of the above.


<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-llm-routing.sh
```
