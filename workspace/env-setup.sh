#!/bin/bash
# ==============================================================================
# Script: env-setup.sh
# Purpose: Configure Cloud Shell workspace, tools, symlinks, and agent dependencies.
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_SYMLINK="$HOME/workspace"
APIGEELLM_DIR="${REPO_ROOT}/adk-cymbal-retail-agent/python/agents/cymbal-retail-agent-apigeellm"

echo "=== [Workspace Setup] Initializing Apigee AI Agents Workshop Environment ==="

# Ensure ~/workspace symlink points to this workspace directory
if [ "$WORKSPACE_SYMLINK" != "$SCRIPT_DIR" ]; then
  echo "✅ Creating ~/workspace symlink -> ${SCRIPT_DIR}..."
  ln -sfn "$SCRIPT_DIR" "$WORKSPACE_SYMLINK"
fi

# Install uv if missing
if ! command -v uv &>/dev/null && [ ! -f "$HOME/.local/bin/uv" ]; then
  echo "✅ Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"

# Install apigeecli if missing
if ! command -v apigeecli &>/dev/null && [ ! -f "$HOME/.apigeecli/bin/apigeecli" ]; then
  echo "✅ Installing apigeecli tool..."
  rm -rf "$HOME/.apigeecli"
  curl -s -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh -
fi
export PATH="$HOME/.apigeecli/bin:$PATH"

# Ensure Python 3.12 is installed via uv
echo "✅ Ensuring Python 3.12 is available..."
uv python install 3.12 2>/dev/null || true

# Sync Python dependencies for cymbal-retail-agent
echo "✅ Installing agent dependencies (workspace/cymbal-retail-agent)..."
pushd "${SCRIPT_DIR}/cymbal-retail-agent" >/dev/null
rm -f uv.lock 2>/dev/null || true
uv sync --python 3.12
uv pip install "google-adk[a2a,agent-identity]" a2a-sdk 2>/dev/null || true
popd >/dev/null

# Sync Python dependencies for cymbal-retail-agent-apigeellm (Task 4)
if [ -d "$APIGEELLM_DIR" ]; then
  echo "✅ Installing agent dependencies (cymbal-retail-agent-apigeellm)..."
  pushd "$APIGEELLM_DIR" >/dev/null
  rm -f uv.lock 2>/dev/null || true
  uv sync --python 3.12
  popd >/dev/null
fi

# Export venv & CLI paths now and persist in ~/.bashrc so bare `adk` always works in every shell
AGENT_PATH_EXPORT='export PATH="$HOME/workspace/cymbal-retail-agent/.venv/bin:$HOME/apigee-samples/workspace/cymbal-retail-agent/.venv/bin:$HOME/.local/bin:$HOME/.apigeecli/bin:$PATH"'
export PATH="$HOME/workspace/cymbal-retail-agent/.venv/bin:$HOME/apigee-samples/workspace/cymbal-retail-agent/.venv/bin:$HOME/.local/bin:$HOME/.apigeecli/bin:$PATH"
if [ -f "$HOME/.bashrc" ] && ! grep -q 'cymbal-retail-agent/\.venv/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo "$AGENT_PATH_EXPORT" >> "$HOME/.bashrc"
fi

# Pre-configure ADK telemetry so first `uv run adk web` never blocks on interactive [Y/n] prompt
adk telemetry disable >/dev/null 2>&1 || true

# Resolve active GCP project, region (auto-detecting lab Cloud Run / Compute region if unset), Apigee hostname, and credentials
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
REGION=$(gcloud config get-value compute/region 2>/dev/null || echo "")
if [ -z "$REGION" ] && [ -n "$PROJECT_ID" ]; then
  REGION=$(gcloud run services list --project="$PROJECT_ID" --limit=1 --format="value(region)" 2>/dev/null || echo "")
fi
if [ -z "$REGION" ] && [ -n "$PROJECT_ID" ]; then
  ZONE_VAL=$(gcloud compute instances list --project="$PROJECT_ID" --limit=1 --format="value(zone)" 2>/dev/null || echo "")
  REGION="${ZONE_VAL%-[a-z]}"
fi
[ -z "$REGION" ] && REGION="us-central1"

TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token 2>/dev/null || echo "")
RESOLVED_APIGEE_HOST=""
LLM_GATEWAY_KEY=""
ADMIN_CLIENT_ID=""
ADMIN_CLIENT_SECRET=""

if [ -n "$PROJECT_ID" ]; then
  # Ensure staging GCS bucket exists for Agent Engine deployments
  gcloud storage buckets create "gs://${PROJECT_ID}_cymbal_retail_agent" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" 2>/dev/null || true

  if [ -n "$TOKEN" ]; then
    RESOLVED_APIGEE_HOST=$(apigeecli envgroups list -o "$PROJECT_ID" -t "$TOKEN" --disable-check 2>/dev/null | jq -r '.environmentGroups[0].hostnames[0] // .[0].hostnames[0] // empty' 2>/dev/null || echo "")

    # Discover dedicated admin app credentials first, falling back to cymbal-retail-app
    ADMIN_APP_JSON=$(apigeecli apps get --name "cymbal-retail-admin-app" --org "$PROJECT_ID" --token "$TOKEN" --disable-check 2>/dev/null || echo "")
    ADMIN_CLIENT_ID=$(echo "$ADMIN_APP_JSON" | jq -r '.[0].credentials[0].consumerKey // empty' 2>/dev/null || echo "")
    ADMIN_CLIENT_SECRET=$(echo "$ADMIN_APP_JSON" | jq -r '.[0].credentials[0].consumerSecret // empty' 2>/dev/null || echo "")

    if [ -z "$ADMIN_CLIENT_ID" ] || [ -z "$ADMIN_CLIENT_SECRET" ]; then
      FALLBACK_APP_JSON=$(apigeecli apps get --name "cymbal-retail-app" --org "$PROJECT_ID" --token "$TOKEN" --disable-check 2>/dev/null || echo "")
      ADMIN_CLIENT_ID=$(echo "$FALLBACK_APP_JSON" | jq -r '.[0].credentials[0].consumerKey // empty' 2>/dev/null || echo "")
      ADMIN_CLIENT_SECRET=$(echo "$FALLBACK_APP_JSON" | jq -r '.[0].credentials[0].consumerSecret // empty' 2>/dev/null || echo "")
    fi

    # Discover LLM AI Gateway consumer key
    LLM_APP_JSON=$(apigeecli apps get --name "llm-ai-gateway-app" --org "$PROJECT_ID" --token "$TOKEN" --disable-check 2>/dev/null || echo "")
    LLM_GATEWAY_KEY=$(echo "$LLM_APP_JSON" | jq -r '.[0].credentials[0].consumerKey // empty' 2>/dev/null || echo "")
  fi

  if [ -z "$LLM_GATEWAY_KEY" ]; then
    LLM_GATEWAY_KEY=$(gcloud secrets versions access latest --secret="llm-ai-gateway-client-id" --project="$PROJECT_ID" 2>/dev/null || echo "")
  fi
  if [ -z "$ADMIN_CLIENT_ID" ]; then
    ADMIN_CLIENT_ID=$(gcloud secrets versions access latest --secret="cymbal-retail-admin-client-id" --project="$PROJECT_ID" 2>/dev/null || gcloud secrets versions access latest --secret="cymbal-retail-client-id" --project="$PROJECT_ID" 2>/dev/null || echo "")
  fi
  if [ -z "$ADMIN_CLIENT_SECRET" ]; then
    ADMIN_CLIENT_SECRET=$(gcloud secrets versions access latest --secret="cymbal-retail-admin-client-secret" --project="$PROJECT_ID" 2>/dev/null || gcloud secrets versions access latest --secret="cymbal-retail-client-secret" --project="$PROJECT_ID" 2>/dev/null || echo "")
  fi
fi

APIGEE_HOST="${RESOLVED_APIGEE_HOST:-api-${PROJECT_ID}.apiservices.dev}"

# Pre-populate workspace/cymbal-retail-agent/.env if not yet customized
ENV_FILE="${SCRIPT_DIR}/cymbal-retail-agent/.env"
if [ ! -f "$ENV_FILE" ] || [ ! -s "$ENV_FILE" ] || grep -q "Paste your config here" "$ENV_FILE" 2>/dev/null; then
  if [ -n "$PROJECT_ID" ]; then
    echo "✅ Pre-populating ${ENV_FILE} with current project settings..."
    cat <<ENVEOF > "$ENV_FILE"
GOOGLE_CLOUD_PROJECT="${PROJECT_ID}"
GOOGLE_CLOUD_LOCATION="${REGION}"
APIGEE_HOSTNAME="${APIGEE_HOST}"

# If using Gemini via Vertex AI on Google Cloud
GOOGLE_GENAI_USE_VERTEXAI="TRUE"
GOOGLE_CLOUD_STORAGE_BUCKET="${PROJECT_ID}_cymbal_retail_agent"
MODEL_NAME="gemini-2.5-flash"
AGENT_SERVICE_ACCOUNT="llm-cymbal-retail-agent@${PROJECT_ID}.iam.gserviceaccount.com"
ENVEOF
  fi
fi

# Populate adk-cymbal-retail-agent/python/agents/cymbal-retail-agent-apigeellm/.env
APIGEELLM_ENV_FILE="${APIGEELLM_DIR}/.env"
if [ -d "$APIGEELLM_DIR" ] && [ -n "$PROJECT_ID" ]; then
  if [ ! -f "$APIGEELLM_ENV_FILE" ] || [ ! -s "$APIGEELLM_ENV_FILE" ] || grep -q "<YOUR_" "$APIGEELLM_ENV_FILE" 2>/dev/null; then
    echo "✅ Pre-populating ${APIGEELLM_ENV_FILE} with Apigee AI Gateway & MCP credentials..."
    cat <<APIGEELLMEOF > "$APIGEELLM_ENV_FILE"
GOOGLE_GENAI_USE_VERTEXAI="TRUE"
GOOGLE_CLOUD_PROJECT="${PROJECT_ID}"
GOOGLE_CLOUD_LOCATION="${REGION}"
APIGEE_HOSTNAME="${APIGEE_HOST}"
APIGEE_LLM="/v1/llm-ai-gateway"
LLM_GATEWAY_KEY="${LLM_GATEWAY_KEY}"
APIKEY="${LLM_GATEWAY_KEY}"
CLIENT_ID="${ADMIN_CLIENT_ID}"
CLIENT_SECRET="${ADMIN_CLIENT_SECRET}"
MODEL_NAME="gemini-2.5-flash"
APIGEELLMEOF
  fi
fi

echo "=== [Workspace Setup] Done! Workspace is ready at ~/workspace ==="