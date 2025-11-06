#!/bin/bash

set -e

export PROJECT_ID=""
export REGION=""
export REASONING_ENGINE_ID="" # You can retrieve this by navigating to your deployed Agent via Agent Engine -> select Agent -> review "Query URL" (it is the value post /reasoningEngines/, example: https://us-central1-aiplatform.googleapis.com/v1/projects/dynolab-153020/locations/us-central1/reasoningEngines/4906346338578333696:query)
export AS_APP="" # Agentspace Application ID, can be retrieved in the GCP UI by navigating to Agentspace -> Apps -> ID (shown in the App landing zone)

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

export PROJECT_NUMBER="$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")"
export REASONING_ENGINE="projects/${PROJECT_NUMBER}/locations/${REGION}/reasoningEngines/${REASONING_ENGINE_ID}"
export DISPLAY_NAME="Cymbal Retail Agent" # Name of Agent for Agentspace Users
export DESCRIPTION="Agent to retrieve customer order, customer profile, shipping information and process returns. This agent can delegate tasks to specialized sub-agents." # Description of Agent for Agentspace users
export TOOL_DESCRIPTION="Agent to retrieve customer order, customer profile, shipping information and process returns. This agent can delegate tasks to specialized sub-agents." # Description of Agent tools for Agentspace users

gcloud services enable dialogflow.googleapis.com discoveryengine.googleapis.com aiplatform.googleapis.com --project "$PROJECT_ID"

curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -H "X-Goog-User-Project: ${PROJECT_NUMBER}" \
https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUMBER}/locations/global/collections/default_collection/engines/${AS_APP}/assistants/default_assistant/agents \
  -d '{
      "displayName": "'"${DISPLAY_NAME}"'",
      "description": "'"${DESCRIPTION}"'",
      "adk_agent_definition": {
        "tool_settings": {
          "tool_description": "'"${TOOL_DESCRIPTION}"'"
        },
        "provisioned_reasoning_engine": {
          "reasoning_engine":
            "'"${REASONING_ENGINE}"'"
        }
      }
  }'