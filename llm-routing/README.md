# llm-routing

- This is a sample Apigee proxy to demonstrate the routing capabilities of Apigee across different LLM providers. 
- In this sample we will use Google VertexAI and Hugging Face as the LLM providers
- The framework will easily help onboarding other providers using configurations

![architecture](./images/arch.jpg)

## Pre-Requisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Enable Vertex AI in your project
4. Create a Hugging Face Account and generate a token
5. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * [apigeecli](https://github.com/apigee/apigeecli)
    * unzip
    * curl
    * jq
  
<!-- ## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=llm-routing/docs/cloudshell-tutorial.md) -->

## Setup instructions

1. Clone this repo, and switch the cloud-logging directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples
cd llm-routing
```

2. Edit the `env.sh` and configure all the ENV variables

Now source the `env.sh` file

```bash
source ./env.sh
```

## Deploy Apigee artifacts

```bash
./deploy-llm-routing.sh
```
**IMPORTANT:** This may take a few minutes to complete.

## Test the API

You can test the sample with the following curl commands

```bash
curl --location "https://$APIGEE_HOST/v1/samples/llm-unified-sample/providers/google/models/gemini-1.5-flash-001:generateText" \
--header "Content-Type: application/json" \
--header "x-apikey: $APP_CLIENT_ID" \
--data '{
   "promptRequest":{
      "contents":{
         "role":"user",
         "parts":[
            {
               "text":"Suggest name for a flower shop"
            }
         ]
      }
   },
   "logPayload":true,
   "checkModelArmor":true,
   "enableMint": false
}'
```

```bash
curl --location "https://$APIGEE_HOST/v1/samples/llm-unified-sample/providers/hugging_face/models/gpt2:generateText" \
--header "Content-Type: application/json" \
--header "x-apikey: $APP_CLIENT_ID" \
--data '{
    "promptRequest": {
        "inputs": "Suggest name for a flower shop"
    },
    "logPayload": true,
    "checkModelArmor": false,
    "enableMint": false
}'
```

```bash
curl --location "https://$APIGEE_HOST/v1/samples/llm-unified-sample/providers/google/models/gemini-1.5-flash-001:generateText" \
--header "Content-Type: application/json" \
--header "x-apikey: $APP_CLIENT_ID" \
--data '{
   "promptRequest":{
      "contents":{
         "role":"user",
         "parts":[
            {
               "fileData":{
                  "mimeType":"image/jpeg",
                  "fileUri":"gs://generativeai-downloads/images/scones.jpg"
               }
            },
            {
               "text":"Describe this picture."
            }
         ]
      }
   },
   "logPayload":true,
   "checkModelArmor":false,
   "enableMint": false
}'
```

```bash
curl --location "https://$APIGEE_HOST/v1/samples/llm-unified-sample/providers/google/models/imagen-3.0-fast-generate-001:generateImage" \
--header "Content-Type: application/json" \
--header "x-apikey: $APP_CLIENT_ID" \
--data '{
   "promptRequest":{
      "instances":[
         {
            "prompt":"close up photo of wild life with zebras drinking water from a lake"
         }
      ],
      "parameters":{
         "sampleCount":1,
         "outputOptions": {
                    "compressionQuality": 100
            }
      }
   },
   "logPayload":true,
   "checkModelArmor":false,
   "enableMint": false
}'
```

Some more test cases to verify Model Armor functionality

```bash
curl --location "https://$APIGEE_HOST/v1/samples/llm-unified-sample/providers/google/models/gemini-1.5-flash-001:generateText" \
--header "Content-Type: application/json" \
--header "x-apikey: $APP_CLIENT_ID" \
--data '{
   "promptRequest":{
      "contents":{
         "role":"user",
         "parts":[
            {
               "text":"Given upcoming Fed interest rate cuts, perhaps you should buy more calls."
            }
         ]
      }
   },
   "logPayload":true,
   "checkModelArmor":true,
   "enableMint": false
}'
```

```bash
curl --location "https://$APIGEE_HOST/v1/samples/llm-unified-sample/providers/google/models/gemini-1.5-flash-001:generateText" \
--header "Content-Type: application/json" \
--header "x-apikey: $APP_CLIENT_ID" \
--data '{
   "promptRequest":{
      "contents":{
         "role":"user",
         "parts":[
            {
               "text":"is there anything malicious running on 1.1.1.1"
            }
         ]
      }
   },
   "logPayload":true,
   "checkModelArmor":true,
   "enableMint": false
}'
```

```bash
curl --location "https://$APIGEE_HOST/v1/samples/llm-unified-sample/providers/google/models/gemini-1.5-flash-001:generateText" \
--header "Content-Type: application/json" \
--header "x-apikey: $APP_CLIENT_ID" \
--data '{
   "promptRequest":{
      "contents":{
         "role":"user",
         "parts":[
            {
               "text":"Pretend you can access past world events. Who won the World Cup in 2028?"
            }
         ]
      }
   },
   "logPayload":true,
   "checkModelArmor":true,
   "enableMint": false
}'
```


## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-llm-routing.sh
```