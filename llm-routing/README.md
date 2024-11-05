# llm-routing

- This is a sample Apigee proxy to demonstrate the routing capabilities of Apigee across different LLM providers. In this sample we will use Google VertexAI and Anthropic as the LLM providers
- The framework will easily help onboarding other providers using configurations

![architecture](./images/arch.jpg)

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

## Routing Logic

The sample uses the [Key Value Map](https://cloud.google.com/apigee/docs/api-platform/cache/key-value-maps) to store the different LLM provider configurations. In this sample, we will create a KVM called `llm-routing-config` which will contain the following target URL configurations for each provider.
  
You can refer to this sample [keyvalue map file](./config/env__envname__llm-routing-config__kvmfile__0.json) that contains the configurations for each provider.

**NOTE:** The `{model}` in the Key Value Map is automically replaced with the model passed in the request by Apigee using Message Template

## Payload

The URL path of the API consists of the provider and the model params, for example `/providers/google/models/gemini-1.5-flash-001` or `/anthropic/models/claude-3-5-sonnet-v2@20241022` which is used by the proxy to do the config lookup and route the calls to the actual provider.

The request payload must match to the provider's specification. 

`x-log-payload` is a header you can use for Apigee to log the calls to Cloud Logging. To log pass the header value as `true`

Similarly, the response sent from the provider is returned as is and Apigee just forwards the response back to the calling client

## Get started

Proceed to this [notebook](llm_routing_v1.ipynb) and follow the steps in the Setup and Testing sections.