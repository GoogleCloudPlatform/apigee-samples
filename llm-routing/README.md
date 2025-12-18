# llm-routing

This is a sample Apigee proxy to demonstrate the routing capabilities of Apigee
across different LLM providers. In this sample we will use Google VertexAI,
Mistral and HuggingFace as the LLM providers.

![architecture](./images/arch.jpg)

## Pre-Requisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)

2. Configure [external
   access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access)
   for API traffic to your Apigee X instance

3. Enable Vertex AI in your project.

   You can do this in the [Cloud Console](https://console.cloud.google.com/apis/library), or via the console:

   ```sh
   PROJECT_ID=set-your-project-id
   gcloud services enable aiplatform.googleapis.com --project "$PROJECT_ID"
   ```

   If you are not sure if Vertex AI is enabled, you can check via gcloud:
   ```sh
   gcloud services list --enabled --project "$PROJECT_ID" | grep aiplatform
   ```

4. Create an account on [HuggingFace](https://huggingface.co/), and create an Access Token enabled for Read Access.

   > The process: Create an Account. Confirm your account by clicking the link int he confirmation email.
   > Signin to Huggingface.co . At the top of the page, click your account icon (circular image) and slide
   > down to "Access Tokens". Click that. Create a new Access Token. Near the top, slide over to the right from
   > "Fine Grained" to "Read", select that. Click "Create Token".

5. From Hugging Face, we are going to use the `Llama-3.1-8B-Instruct` model from Meta.

   > You need to agree to share your contact information to access this model

   To do so, after signing in and obtaining an API Key, visit the
   [Llama-3.1-8B-Instruct](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct)
   page and accept the terms.

6. Create an account [Mistral.AI](https://console.mistral.ai/), and create an API Key.

   > The process: Create an account. When signed in, on the left-hand-side navigation menu, slide down to
   > API Keys. Click it.  In the banner, click through to "Subscribe" to the free experimental plan. Confirm your
   > phone number. You will then see "AI Studio". Again use the left-hand-side navigation to slide down to API Keys.
   > Click it.  Then click the button to Create an API Key.


7. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    - [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    - [apigeecli](https://github.com/apigee/apigeecli)
    - unzip
    - curl
    - jq

## Get started

Proceed to this [notebook](llm_routing_v1.ipynb) and follow the steps in the Setup and Testing sections.
