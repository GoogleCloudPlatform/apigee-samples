# Circuit Breaking

This sample creates an LLM proxy with 2 target pools: Primary and Secondary. Each target represents a distinct GCP project with its own Gemini quota. It will also create a Cloud Task queue to simulate a burst of API calls intended to reach and exceed the Primary target quota. the LLM proxy will automatically retry the overflowing calls to the Secondary target pool.

Let's get started!
---

## Prepare project dependencies

### 1. Select the project with an active Apigee instance

<walkthrough-project-setup></walkthrough-project-setup>

### 2. Ensure you have an active GCP account selected in the Cloud Shell

```sh
gcloud auth login
```

### 3. Ensure you have an active GCP account selected in the Cloud Shell

```sh
gcloud config set project <walkthrough-project-id/>
```
### 4. Enable the Services required to deploy this sample

```sh
gcloud services enable aiplatform.googleapis.com tasks.googleapis.com  --project <walkthrough-project-id/>
```

## Set environment variables

### 1. Edit the following variables in the `env.sh` file

Open the environment variables file <walkthrough-editor-open-file filePath="llm-circuit-breaking/env.sh">env.sh</walkthrough-editor-open-file> and set the following variables:

* Set the <walkthrough-editor-select-regex filePath="llm-circuit-breaking/env.sh" regex="APIGEE_PROJECT_ID_TO_SET">APIGEE_PROJECT</walkthrough-editor-select-regex>. The value should be <walkthrough-project-id/>.
* Set the <walkthrough-editor-select-regex filePath="llm-circuit-breaking/env.sh" regex="PROJECT_P1_TO_SET">PROJECT_P1</walkthrough-editor-select-regex>. The project used as Primary tenancy bucket. It can be <walkthrough-project-id/> or a different project with Gemini quota.
* Set the <walkthrough-editor-select-regex filePath="llm-circuit-breaking/env.sh" regex="PROJECT_P2_TO_SET">PROJECT_P2</walkthrough-editor-select-regex>. The project used as Secondary tenancy bucket. It can be <walkthrough-project-id/> or a different project with Gemini quota.
* Set the <walkthrough-editor-select-regex filePath="llm-circuit-breaking/env.sh" regex="REGION_P1_TO_SET">REGION_P1</walkthrough-editor-select-regex>. The region used as Primary tenancy bucket.
* Set the <walkthrough-editor-select-regex filePath="llm-circuit-breaking/env.sh" regex="REGION_P2_TO_SET">REGION_P2</walkthrough-editor-select-regex>. The region used as Secondary tenancy bucket.
* Set the <walkthrough-editor-select-regex filePath="llm-circuit-breaking/env.sh" regex="APIGEE_HOST_TO_SET">APIGEE_HOST</walkthrough-editor-select-regex> of your Apigee instance. For example, `my-test.nip.io`.
* Set the <walkthrough-editor-select-regex filePath="llm-circuit-breaking/env.sh" regex="APIGEE_ENV_TO_SET">APIGEE_ENV</walkthrough-editor-select-regex> to the deploy the sample Apigee artifacts. For example, `dev-env`.

### 2. Set environment variables

```sh
cd llm-circuit-breaking && source ./env.sh
```

## Create a Task Queue

This task queue will allow you to send concurrent request to an LLM endpoint.

### 1. Create a Queue

```sh
gcloud tasks queues create ai-queue --location=$REGION_P1
```

## Deploy sample artifacts

### Execute deployment script

```sh
./deploy-llm-circuit-breaking.sh
```

## Congratulations

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

You're all set!

You can now go back to the [Colab notebook](https://github.com/GoogleCloudPlatform/apigee-samples/blob/main/llm-circuit-breaking/llm_circuit_breaking.ipynb) to test the sample.

**Don't forget to clean up after yourself**. Execute the following script to undeploy and delete all sample resources.
```sh
./undeploy-llm-circuit-breaking.sh
```