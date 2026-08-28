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
if [ -z "$PROJECT_ID" ] && [ -f "env.sh" ] && ! grep -q "PROJECT_ID_TO_SET" env.sh; then
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
SA_EMAIL="${SERVICE_ACCOUNT_NAME:-llm-cymbal-retail-agent}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "--> Granting Cloud Run Invoker role to $SA_EMAIL..."
gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.invoker" \
  --quiet || true

# 6. Pre-warm Gemma 2 (vLLM) on Cloud Run
echo ""
echo "=================================================================="
echo "  Pre-warming Gemma 2 Model Instance                              "
echo "=================================================================="
ID_TOKEN=$(gcloud auth print-identity-token 2>/dev/null || true)
AUTH_HEADER=""
if [ -n "$ID_TOKEN" ]; then
  AUTH_HEADER="Authorization: Bearer $ID_TOKEN"
fi

echo "--> Checking model health on ${SERVICE_URL}..."
MAX_RETRIES=20
RETRY_COUNT=0
IS_READY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  HEALTH_RESP=$(curl -s -k -H "$AUTH_HEADER" "${SERVICE_URL}/health" 2>/dev/null || true)
  if [ "$HEALTH_RESP" == "OK" ] || [ -n "$HEALTH_RESP" ]; then
    IS_READY=true
    break
  fi
  echo "    Waiting for vLLM container to initialize ($((RETRY_COUNT * 10))s elapsed)..."
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ "$IS_READY" = true ]; then
  echo "--> Executing pre-warming test invocation..."
  WARMUP_RESP=$(curl -s -k -X POST "${SERVICE_URL}/v1/chat/completions" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"${MODEL_ID}\",
      \"messages\": [{\"role\": \"user\", \"content\": \"Pre-warming test. Respond with OK.\"}],
      \"max_tokens\": 10
    }")
  
  CONTENT=$(echo "$WARMUP_RESP" | grep -o '"content":"[^"]*"' | head -n 1 || true)
  if [ -n "$CONTENT" ]; then
    echo "--> Pre-warm test successful! Received: $CONTENT"
  else
    echo "--> Pre-warm response: $WARMUP_RESP"
  fi
  echo "✅ Gemma 2 instance pre-warmed and ready for student traffic!"
else
  echo "⚠️ Warning: Pre-warming check timed out."
fi

echo ""
echo "Sample Test Command:"
echo "TOKEN=\$(gcloud auth print-identity-token)"
echo "curl -X POST ${SERVICE_URL}/v1/chat/completions \\"
echo "  -H \"Authorization: Bearer \$TOKEN\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"model\": \"${MODEL_ID}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello Gemma!\"}]}'"

