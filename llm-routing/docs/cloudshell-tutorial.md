# llm-routing

---

- This is a sample Apigee proxy to demonstrate the routing capabilities of Apigee across different LLM providers. In this sample we will use Google VertexAI and Anthropic as the LLM providers
- The framework will easily help onboarding other providers using configurations

## Pre-Requisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Enable Vertex AI in your project
4. Enable Anthropic in your [Vertex AI Model Garden](https://cloud.google.com/model-garden)
5. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
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

Export the `APP_CLIENT_ID` variable as mentioned in the command output

---

## Verification

You can test the sample with the following curl commands:

### To Gemini

Provide your Provide and Model names in the follow variables:

```sh
PROVIDER=google
MODEL=gemini-1.5-flash-001
```
Run this curl command

```sh
curl --location "https://$APIGEE_HOST/v1/samples/llm-routing/v1/projects/$PROJECT_ID/locations/us-east1/publishers/$PROVIDER/models/$MODEL:generateContent" \
--header "Content-Type: application/json" \
--header "x-log-payload: false" \
--header "x-apikey: $APP_CLIENT_ID" \
--data '{
      "contents":{
         "role":"user",
         "parts":[
            {
               "text":"Suggest name for a flower shop"
            }
         ]
      }
}'
```

### To Anthropic

Similarly now for Anthropic, provide your model name

```sh
PROVIDER=anthropic
MODEL=claude-3-5-sonnet-v2@20241022
```

and execute the curl command

```sh
curl --location "https://$APIGEE_HOST/v1/samples/llm-routing/v1/projects/$PROJECT_ID/locations/us-east5/publishers/$PROVIDER/models/$MODEL:rawPredict" \
--header "Content-Type: application/json" \
--header "x-log-payload: false" \
--header "x-apikey: $APP_CLIENT_ID" \
--data '{
    "anthropic_version": "vertex-2023-10-16",
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": "Suggest name for a flower shop"
                }
            ]
        }
    ],
    "max_tokens": 256,
    "stream": false
}'
```

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed Apigee proxy to route calls to different LLM providers

You can now go back to the [notebook](../llm_routing_v1.ipynb) to test the sample.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-llm-routing.sh
```
