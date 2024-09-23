# Logging

This sample creates and deploys an LLM proxy that logs prompts and candidate responses. It will also create and deploy helper sharedflows with core logging logic to be reused.

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
gcloud services enable aiplatform.googleapis.com logging.googleapis.com  --project <walkthrough-project-id/>
```

### 4. Create a service account to be used by the sample

```sh
gcloud iam service-accounts create ai-logger --description="Logging client" --display-name="ai-logger"
```

### 5. Assign the Logging Writer role to the service account

```sh
gcloud projects add-iam-policy-binding <walkthrough-project-id/> --member="serviceAccount:ai-logger@<walkthrough-project-id/>.iam.gserviceaccount.com" --role="roles/logging.logWriter"
```

## Set environment variables

### 1. Edit the following variables in the `env.sh` file

Open the environment variables file <walkthrough-editor-open-file filePath="llm-logging/env.sh">env.sh</walkthrough-editor-open-file> and set the following variables:

* Set the <walkthrough-editor-select-regex filePath="llm-logging/env.sh" regex="APIGEE_PROJECT_ID_TO_SET">APIGEE_PROJECT</walkthrough-editor-select-regex>. The value should be <walkthrough-project-id/>.
* Set the <walkthrough-editor-select-regex filePath="llm-logging/env.sh" regex="PROJECT_P1_TO_SET">PROJECT_P1</walkthrough-editor-select-regex>. The project used as Primary tenancy bucket. It can be <walkthrough-project-id/> or a different project with Gemini quota.
* Set the <walkthrough-editor-select-regex filePath="llm-logging/env.sh" regex="REGION_P1_TO_SET">REGION_P1</walkthrough-editor-select-regex>. The region used as Primary tenancy bucket.
* Set the <walkthrough-editor-select-regex filePath="llm-logging/env.sh" regex="APIGEE_HOST_TO_SET">APIGEE_HOST</walkthrough-editor-select-regex> of your Apigee instance. For example, `my-test.nip.io`.
* Set the <walkthrough-editor-select-regex filePath="llm-logging/env.sh" regex="APIGEE_ENV_TO_SET">APIGEE_ENV</walkthrough-editor-select-regex> to the deploy the sample Apigee artifacts. For exanple, `dev-env`.

### 2. Set environment variables

```sh
cd llm-logging && source ./env.sh
```
## Deploy sample artifacts

### Execute deployment script

```sh
./deploy-llm-logging.sh
```

## Congratulations

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

You're all set!

You can now go back to the [notebook](https://github.com/GoogleCloudPlatform/apigee-samples/blob/main/llm-logging/llm_logging_v1.ipynb) to test the sample.

**Don't forget to clean up after yourself**. Execute the following script to undeploy and delete all sample resources.
```sh
./undeploy-llm-logging.sh
```