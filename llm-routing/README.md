# llm-routing

This is a sample Apigee proxy to demonstrate the routing capabilities of Apigee across different LLM providers. In this sample we will use Google VertexAI, Mistral and HuggingFace as the LLM providers

![architecture](./images/arch.jpg)

## Pre-Requisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Enable Vertex AI in your project
4. Create a [HuggingFace Account](https://huggingface.co/) and create an API Key
5. Similar to HuggingFace, create a [Mistral Account](https://console.mistral.ai/) and create an API Key
6. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    - [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    - [apigeecli](https://github.com/apigee/apigeecli)
    - unzip
    - curl
    - jq

## Get started

Proceed to this [notebook](llm_routing_v1.ipynb) and follow the steps in the Setup and Testing sections.