# Semantic Cache

This sample performs a cache lookup of responses on Apigee's Cache layer and Vector Search as an embeddings database. It operates by comparing the vector proximity of the prompt to prior requests and using a configurable similarity score threshold.

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

### 4. Enable the Services requiered to deploy this sample

```sh
gcloud services enable compute.googleapis.com aiplatform.googleapis.com storage.googleapis.com integrations.googleapis.com  --project <walkthrough-project-id/>
```

## Edit the following variables in the provided `env.sh` file

Open the environment variables file <walkthrough-editor-open-file filePath="llm-semantic-cache/env.sh">env.sh</walkthrough-editor-open-file> and set the following variables:

* Set the <walkthrough-editor-select-regex filePath="llm-semantic-cache/env.sh" regex="PROJECT_ID_TO_SET">PROJECT_ID</walkthrough-editor-select-regex>. The value should be <walkthrough-project-id/>.
* Set the <walkthrough-editor-select-regex filePath="llm-semantic-cache/env.sh" regex="REGION_TO_SET">REGION</walkthrough-editor-select-regex> to deploy the Vector Search Index. It should be the same region as your Apigee instance.
* Set the <walkthrough-editor-select-regex filePath="llm-semantic-cache/env.sh" regex="MODEL_ID_TO_SET">MODEL_ID</walkthrough-editor-select-regex> to send generative prompts to. For example, `gemini-1.5-pro-001`.
* Set the <walkthrough-editor-select-regex filePath="llm-semantic-cache/env.sh" regex="EMBEDDINGS_MODEL_ID_TO_SET">EMBEDDINGS_MODEL_ID</walkthrough-editor-select-regex> to generate embeddings with. For example, `text-embedding-004`.
* Set the <walkthrough-editor-select-regex filePath="llm-semantic-cache/env.sh" regex="NEAREST_NEIGHBOR_DISTANCE_TO_SET">NEAREST_NEIGHBOR_DISTANCE</walkthrough-editor-select-regex> that will be used to perform nearest neighbor lookups on an embeddings database. The bigger the number, the more closely prompts have to be related to be considered a cache hit. For exsample, `0.95`.
* Set the <walkthrough-editor-select-regex filePath="llm-semantic-cache/env.sh" regex="CACHE_ENTRY_TTL_SEC_TO_SET">CACHE_ENTRY_TTL_SEC</walkthrough-editor-select-regex> that will be used to assing TTL for cache entries in seconds.  For exsample, `60`.
* Set the <walkthrough-editor-select-regex filePath="llm-semantic-cache/env.sh" regex="APIGEE_HOST_TO_SET">APIGEE_HOST</walkthrough-editor-select-regex> of your Apigee instance. For example, `my-test.nip.io`.
* Set the <walkthrough-editor-select-regex filePath="llm-semantic-cache/env.sh" regex="APIGEE_ENV_TO_SET">APIGEE_ENV</walkthrough-editor-select-regex> to the deploy the sample Apigee artifacts. For exanple, `dev-env`.

### Set environment variables

```sh
cd llm-semantic-cache && source ./env.sh
```

## Create and deploy a Vector Search index

### Create an index

The following `curl` command will create an index that will allow streaming updates.

```sh
ACCESS_TOKEN=$(gcloud auth print-access-token) \
curl --location --request POST "https://$REGION-aiplatform.googleapis.com/v1/projects/$PROJECT/locations/$REGION/indexes" \
--header "Authorization: Bearer $ACCESS_TOKEN" \
--header 'Content-Type: application/json' \
--data-raw '{"displayName": "semantic-cache", "description": "semantic-cache", "metadata": {"config": {"dimensions": "768","approximateNeighborsCount": 150,"distanceMeasureType": "DOT_PRODUCT_DISTANCE","featureNormType": "NONE","algorithmConfig": {"treeAhConfig": {"leafNodeEmbeddingCount": "10000","fractionLeafNodesToSearch": 0.05}},"shardSize": "SHARD_SIZE_MEDIUM"},},"indexUpdateMethod": "STREAM_UPDATE"}'
```
### Create an index endpoint

```sh
gcloud ai index-endpoints create  --display-name=semantic-cache --public-endpoint-enabled --region=$REGION --project=$PROJECT
```

### Deploy index to the endpoint

```sh
INDEX_ENDPOINT_ID=$(gcloud ai index-endpoints list --project=$PROJECT --region=$REGION --format="json" | jq -c -r '.[] | select(.displayName="semantic-cache") | .name | split("/") | .[5]') \
INDEX_ID=$(gcloud ai indexes list --project=$PROJECT --region=$REGION --format="json" | jq -c -r '.[] | select(.displayName="semantic-cache") | .name | split("/") | .[5]') \
gcloud ai index-endpoints deploy-index $INDEX_ENDPOINT_ID --deployed-index-id=semantic_cache --display-name=semantic-cache --index=$INDEX_ID --region=$REGION --project=$PROJECT
```

**Important:** Initial deployment of an index to an endpoint typically takes between 20 and 30 minutes.

## Deploy sample artifacts

### Create a service account to be used by the sample

```sh
gcloud iam service-accounts create ai-client --description="semantic cache client" --display-name="ai-client"
```

### Assign Vertex AI Platform User Role to the service account

```sh
gcloud projects add-iam-policy-binding <walkthrough-project-id/> --member="serviceAccount:ai-client@<walkthrough-project-id/>.iam.gserviceaccount.com" --role="roles/aiplatform.user"
```

### Execute deployment script

```sh
./deploy-llm-semantic-cache.sh
```

## Congratulations

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

You're all set!

You can now go back to the [Colab notebook](https://github.com/ra2085/apigee-samples/blob/main/llm-semantic-cache/llm_semantic_cache_v1.ipynb) to test the sample.

**Don't forget to clean up after yourself**. Execute the following script to undeploy and delete all sample resources.
```sh
./undeploy-llm-semantic-cache.sh
```