# Token Limits

This sample creates tiered Products to limit and control the token consumption. It also camptures token metrics that are aggregated on a report.

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
## Set environment variables

## 1. Edit the following variables in the `env.sh` file

Open the environment variables file <walkthrough-editor-open-file filePath="llm-token-limits/env.sh">env.sh</walkthrough-editor-open-file> and set the following variables:

* Set the <walkthrough-editor-select-regex filePath="llm-token-limits/env.sh" regex="PROJECT_ID_TO_SET">PROJECT_ID</walkthrough-editor-select-regex>. The value should be <walkthrough-project-id/>.
* Set the <walkthrough-editor-select-regex filePath="llm-token-limits/env.sh" regex="APIGEE_HOST_TO_SET">APIGEE_HOST</walkthrough-editor-select-regex> of your Apigee instance. For example, `my-test.nip.io`.
* Set the <walkthrough-editor-select-regex filePath="llm-token-limits/env.sh" regex="APIGEE_ENV_TO_SET">APIGEE_ENV</walkthrough-editor-select-regex> to the deploy the sample Apigee artifacts. For exanple, `dev-env`.

### 2. Set environment variables

```sh
cd llm-token-limits && source ./env.sh
```

## Deploy sample artifacts

### Execute deployment script

```sh
./deploy-llm-token-limits.sh
```

## Congratulations

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

You're all set!

You can now go back to the [Colab notebook](https://github.com/ra2085/apigee-samples/blob/main/llm-token-limits/llm_semantic_cache_v1.ipynb) to test the sample.

**Don't forget to clean up after yourself**. Execute the following script to undeploy and delete all sample resources.
```sh
./undeploy-llm-token-limits.sh
```