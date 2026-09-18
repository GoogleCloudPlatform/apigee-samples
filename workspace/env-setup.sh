#!/bin/bash
# ==============================================================================
# Script: env-setup.sh
# Purpose: Configure Cloud Shell workspace, tools, symlinks, and agent dependencies.
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_SYMLINK="$HOME/workspace"

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

# Ensure PATH is persisted in ~/.bashrc
if [ -f "$HOME/.bashrc" ] && ! grep -q '\.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$HOME/.apigeecli/bin:$PATH"' >> "$HOME/.bashrc"
fi

# Ensure Python 3.12 is installed via uv
echo "✅ Ensuring Python 3.12 is available..."
uv python install 3.12 2>/dev/null || true

# Sync Python dependencies for cymbal-retail-agent
echo "✅ Installing agent dependencies..."
pushd "${SCRIPT_DIR}/cymbal-retail-agent" >/dev/null
rm -f uv.lock 2>/dev/null || true
uv sync --python 3.12
uv pip install "google-adk[a2a,agent-identity]" a2a-sdk 2>/dev/null || true
popd >/dev/null

# Pre-populate .env if not yet customized
ENV_FILE="${SCRIPT_DIR}/cymbal-retail-agent/.env"
if [ ! -f "$ENV_FILE" ] || [ ! -s "$ENV_FILE" ] || grep -q "Paste your config here" "$ENV_FILE" 2>/dev/null; then
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
  REGION=$(gcloud config get-value compute/region 2>/dev/null || echo "us-central1")
  [ -z "$REGION" ] && REGION="us-central1"
  APIGEE_HOST="api-${PROJECT_ID}.apiservices.dev"
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

echo "=== [Workspace Setup] Done! Workspace is ready at ~/workspace ==="