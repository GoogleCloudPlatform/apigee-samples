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
  --min-instances=0 \
  --max-instances=1 \
  --no-cpu-throttling \
  --region="$REGION" \
  --allow-unauthenticated \
  --project="$PROJECT_ID"

# ==============================================================================
# Step 3: Retrieve Deployed Service URL
# ==============================================================================
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)")
echo "=================================================================="
echo "  Gemma 3 CPU Service Deployed Successfully!                      "
echo "  Endpoint URL: $SERVICE_URL"
echo "=================================================================="

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

echo ""
echo "Sample Test Command:"
echo "curl -X POST ${SERVICE_URL}/v1/chat/completions \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"model\": \"${MODEL_NAME}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello Gemma! What can you do?\"}]}'"
