#!/bin/bash

set -e

export PROJECT_ID="${PROJECT_ID:-}"
export REGION="${REGION:-}"
export REASONING_ENGINE_ID="${REASONING_ENGINE_ID:-}" # Retrieve from your deployed Agent output (the numeric ID after /reasoningEngines/)
export AS_APP="${AS_APP:-gemini-enterprise}" # Gemini Enterprise / Agentspace Application ID

if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
fi

if [ -z "$REGION" ]; then
  REGION="$(gcloud config get-value compute/region 2>/dev/null || true)"
fi

# Normalize in case full resource path or :query URL was pasted
REASONING_ENGINE_ID="${REASONING_ENGINE_ID##*/}"
REASONING_ENGINE_ID="${REASONING_ENGINE_ID%%:*}"

if [ -z "$PROJECT_ID" ]; then
  echo "No PROJECT_ID variable set"
  exit 1
fi

if [ -z "$REGION" ]; then
  echo "No REGION variable set"
  exit 1
fi

if [ -z "$REASONING_ENGINE_ID" ]; then
  echo "No REASONING_ENGINE_ID variable set"
  exit 1
fi

if [ -z "$AS_APP" ]; then
  echo "No AS_APP variable set"
  exit 1
fi

export PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")"
export REASONING_ENGINE="projects/${PROJECT_NUMBER}/locations/${REGION}/reasoningEngines/${REASONING_ENGINE_ID}"
export DISPLAY_NAME="Cymbal Retail Agent" # Name of Agent for Gemini Enterprise Users
export DESCRIPTION="Agent to retrieve customer order, customer profile, shipping information and process returns. This agent can delegate tasks to specialized sub-agents."
export TOOL_DESCRIPTION="Agent to retrieve customer order, customer profile, shipping information and process returns. This agent can delegate tasks to specialized sub-agents."

gcloud services enable dialogflow.googleapis.com discoveryengine.googleapis.com aiplatform.googleapis.com --project "$PROJECT_ID"

curl -f -sS -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -H "X-Goog-User-Project: ${PROJECT_NUMBER}" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUMBER}/locations/global/collections/default_collection/engines/${AS_APP}/assistants/default_assistant/agents" \
  -d '{
      "displayName": "'"${DISPLAY_NAME}"'",
      "description": "'"${DESCRIPTION}"'",
      "adk_agent_definition": {
        "tool_settings": {
          "tool_description": "'"${TOOL_DESCRIPTION}"'"
        },
        "provisioned_reasoning_engine": {
          "reasoning_engine": "'"${REASONING_ENGINE}"'"
        }
      }
  }'
echo ""
