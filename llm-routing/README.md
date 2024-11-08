# llm-routing

- This is a sample Apigee proxy to demonstrate the routing capabilities of Apigee across different LLM providers. In this sample we will use Google VertexAI and Anthropic as the LLM providers
- The framework will easily help onboarding other providers using configurations

![architecture](./images/arch.jpg)

## Pre-Requisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Enable Vertex AI in your project
4. Enable Anthropic in your [Vertex AI Model Garden](https://cloud.google.com/model-garden) and provision any model for example `claude-3-5-sonnet-v2@20241022`
5. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    - [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    - [apigeecli](https://github.com/apigee/apigeecli)
    - unzip
    - curl
    - jq

## Get started

Proceed to this [notebook](llm_routing_v1.ipynb) and follow the steps in the Setup and Testing sections.