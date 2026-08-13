#!/bin/bash

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# Load environment configuration if available
if [ -f "env.sh" ]; then
  source env.sh
fi

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
REGION="${VERTEXAI_REGION:-us-central1}"
SERVICE_NAME="gemma-2-9b-private-router"
MODEL_ID="google/gemma-2-9b-it"

echo "=================================================================="
echo "  Deploying Gemma 2 (vLLM) to Cloud Run with GPU (Scale-to-Zero)  "
echo "=================================================================="
echo "  Project:   $PROJECT_ID"
echo "  Region:    $REGION"
echo "  Service:   $SERVICE_NAME"
echo "  Model:     $MODEL_ID"
echo "=================================================================="

# 1. Enable required GCP services
echo "--> Enabling Cloud Run and Compute APIs..."
gcloud services enable \
  run.googleapis.com \
  compute.googleapis.com \
  artifactregistry.googleapis.com \
  --project "$PROJECT_ID"

# 2. Check if Hugging Face token is provided for gated model weights
HF_TOKEN="${HF_TOKEN:-$HUGGING_FACE_HUB_TOKEN}"
ENV_FLAGS=""
if [ -n "$HF_TOKEN" ]; then
  echo "--> Configured Hugging Face Hub token for model download."
  ENV_FLAGS="--set-env-vars=HUGGING_FACE_HUB_TOKEN=${HF_TOKEN},HF_TOKEN=${HF_TOKEN}"
fi

# 3. Deploy vLLM container to Cloud Run with NVIDIA L4 GPU
echo "--> Deploying Cloud Run service with NVIDIA L4 GPU..."
gcloud run deploy "$SERVICE_NAME" \
  --image="vllm/vllm-openai:latest" \
  --args="--model,${MODEL_ID},--max-model-len,4096,--gpu-memory-utilization,0.90,--port,8080" \
  --port=8080 \
  --gpu=1 \
  --gpu-type=nvidia-l4 \
  --cpu=8 \
  --memory=32Gi \
  --min-instances=0 \
  --max-instances=2 \
  --no-cpu-throttling \
  --region="$REGION" \
  --no-allow-unauthenticated \
  --project="$PROJECT_ID" \
  $ENV_FLAGS

# 4. Retrieve Service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)")
echo "=================================================================="
echo "  Gemma 2 Cloud Run Service Deployed Successfully!                "
echo "  Endpoint URL: $SERVICE_URL"
echo "=================================================================="

# 5. Grant Apigee / Agent Service Account invoker permissions
if [ -n "$SERVICE_ACCOUNT_NAME" ]; then
  SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
  echo "--> Granting Cloud Run Invoker role to $SA_EMAIL..."
  gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/run.invoker" \
    --quiet || true
fi

echo ""
echo "Sample Test Command:"
echo "TOKEN=\$(gcloud auth print-identity-token)"
echo "curl -X POST ${SERVICE_URL}/v1/chat/completions \\"
echo "  -H \"Authorization: Bearer \$TOKEN\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"model\": \"${MODEL_ID}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello Gemma!\"}]}'"
