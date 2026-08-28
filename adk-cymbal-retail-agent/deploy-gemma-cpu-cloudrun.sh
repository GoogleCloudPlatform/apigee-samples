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

# Load environment configuration if valid
PROJECT_ID_CURRENT=$(gcloud config get-value project 2>/dev/null)
if [ -f "env.sh" ] && ! grep -q "PROJECT_ID_TO_SET" env.sh; then
  source env.sh
fi

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
if [ "$PROJECT_ID" == "PROJECT_ID_TO_SET" ] || [ -z "$PROJECT_ID" ]; then
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
fi

REGION="${VERTEXAI_REGION:-us-central1}"
if [ "$REGION" == "VERTEXAI_REGION_TO_SET" ] || [ -z "$REGION" ]; then
  REGION="us-central1"
fi

SERVICE_NAME="gemma-cpu-router"
MODEL_NAME="${MODEL_NAME:-gemma3:4b}"
if [ "$MODEL_NAME" == "gemini-2.5-flash" ]; then
  MODEL_NAME="gemma3:4b"
fi

echo "=================================================================="
echo "  Deploying CPU-Optimized Gemma 3 (4B) to Cloud Run (Qwiklabs)   "
echo "=================================================================="
echo "  Project:   $PROJECT_ID"
echo "  Region:    $REGION"
echo "  Service:   $SERVICE_NAME"
echo "  Model:     $MODEL_NAME (Gemma 3 4B CPU-optimized)"
echo "=================================================================="

# ==============================================================================
# Step 1: Enable required GCP Services
# ==============================================================================
echo "--> Enabling Cloud Run and Artifact Registry APIs..."
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  --project "$PROJECT_ID"

# ==============================================================================
# Step 2: Deploy Ollama container with Gemma 3 (4B) on standard Cloud Run CPU
# Key configurations:
#  - Uses official ollama/ollama:latest image.
#  - Startup command starts Ollama daemon in background, pulls quantized model weights (~2.8GB in ~20s), and waits.
#  - 4 vCPUs & 8GB RAM provides ~18-25 tokens/sec generation on standard CPU compute quotas.
#  - --min-instances=0 enables full scale-to-zero ($0 idle cost for workshops).
# ==============================================================================
echo "--> Deploying Cloud Run service with 4 vCPUs and 8GB RAM..."
gcloud run deploy "$SERVICE_NAME" \
  --image="ollama/ollama:latest" \
  --command="sh" \
  --args="-c,ollama serve & PID=\$!; sleep 3; ollama pull ${MODEL_NAME}; wait \$PID" \
  --port=11434 \
  --cpu=4 \
  --memory=8Gi \
  --min-instances=1 \
  --max-instances=3 \
  --concurrency=2 \
  --timeout=300 \
  --no-cpu-throttling \
  --region="$REGION" \
  --no-allow-unauthenticated \
  --project="$PROJECT_ID"


# ==============================================================================
# Step 3: Retrieve Deployed Service URL & Configure IAM Permissions
# ==============================================================================
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)")

SA_EMAIL="apigee-vertex-ai-caller@${PROJECT_ID}.iam.gserviceaccount.com"
echo "--> Granting Cloud Run Invoker role (roles/run.invoker) to $SA_EMAIL..."
gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/run.invoker" \
  --region="$REGION" \
  --project="$PROJECT_ID" >/dev/null 2>&1 || true

echo "=================================================================="
echo "  Gemma 3 CPU Service Deployed Successfully!                      "
echo "  Endpoint URL: $SERVICE_URL"
echo "=================================================================="

SA_EMAIL="${SERVICE_ACCOUNT_NAME:-llm-cymbal-retail-agent}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "--> Granting Cloud Run Invoker role to $SA_EMAIL..."
gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.invoker" \
  --quiet || true

# ==============================================================================
# Step 4: Update Apigee AI Gateway Gemma propertyset configuration
# Injects the active Cloud Run URL into proxies/.../gemma_config.properties
# ==============================================================================
CONFIG_FILE="proxies/adk-retail-agent-llm-governance-v1/apiproxy/resources/properties/gemma_config.properties"
if [ -f "$CONFIG_FILE" ]; then
  echo "--> Updating Apigee configuration in $CONFIG_FILE..."
  cat << PROP > "$CONFIG_FILE"
gemma_url=${SERVICE_URL}/v1/chat/completions
model_id=${MODEL_NAME}
PROP
fi

# ==============================================================================
# Step 5: Pre-warm Gemma 3 (4B) on Cloud Run (Qwiklabs Readiness Step)
# 1. Polls /api/tags until model download/initialization completes
# 2. Issues test warm-up completion request to ensure 0-latency first-token for students
# ==============================================================================
echo ""
echo "=================================================================="
echo "  Step 5: Pre-warming Gemma 3 Model Instance                      "
echo "=================================================================="
ID_TOKEN=$(gcloud auth print-identity-token 2>/dev/null || true)
AUTH_HEADER=""
if [ -n "$ID_TOKEN" ]; then
  AUTH_HEADER="Authorization: Bearer $ID_TOKEN"
fi

echo "--> Checking model readiness on ${SERVICE_URL}..."
MAX_RETRIES=20
RETRY_COUNT=0
IS_READY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  TAGS_RESP=$(curl -s -k -H "$AUTH_HEADER" "${SERVICE_URL}/api/tags" 2>/dev/null || true)
  if echo "$TAGS_RESP" | grep -q "${MODEL_NAME}"; then
    IS_READY=true
    break
  fi
  echo "    Waiting for model '${MODEL_NAME}' to download and initialize in container ($((RETRY_COUNT * 10))s elapsed)..."
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ "$IS_READY" = true ]; then
  echo "--> Model '${MODEL_NAME}' is loaded! Initializing model runner..."
  sleep 5
  
  echo "--> Executing pre-warming test invocation..."
  WARMUP_SUCCESS=false
  for ATTEMPT in 1 2 3; do
    WARMUP_RESP=$(curl -s -k -X POST "${SERVICE_URL}/v1/chat/completions" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"${MODEL_NAME}\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Pre-warming test. Answer in 1 word: Pong.\"}],
        \"max_tokens\": 10
      }" 2>/dev/null || true)
    
    CONTENT=$(echo "$WARMUP_RESP" | grep -o '"content":"[^"]*"' | head -n 1 || true)
    if [ -n "$CONTENT" ]; then
      echo "--> Pre-warm test successful! Received: $CONTENT"
      WARMUP_SUCCESS=true
      break
    else
      echo "    Warm-up attempt $ATTEMPT/3 returned: $WARMUP_RESP. Retrying in 5s..."
      sleep 5
    fi
  done

  if [ "$WARMUP_SUCCESS" = true ]; then
    echo "✅ Gemma 3 instance pre-warmed and ready for student traffic!"
  else
    echo "⚠️ Warning: Pre-warming test invocation did not complete successfully."
  fi
else
  echo "⚠️ Warning: Pre-warming wait timed out. Container may still be pulling weights in background."
fi


echo ""
echo "Sample Test Command:"
echo "TOKEN=\$(gcloud auth print-identity-token)"
echo "curl -X POST ${SERVICE_URL}/v1/chat/completions \\"
echo "  -H \"Authorization: Bearer \$TOKEN\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"model\": \"${MODEL_NAME}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello Gemma! What can you do?\"}], \"max_tokens\": 2000}'"


