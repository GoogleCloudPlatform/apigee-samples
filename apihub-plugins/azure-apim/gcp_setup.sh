#!/bin/bash

# Copyright 2025 Google LLC
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

read -p "Enter your Google Cloud Project ID: " PROJECT_ID
read -p "Enter the Google Cloud Region for API Hub & Integration: " REGION

SERVICE_ACCOUNT_NAME="azure-apim-integration-sa"
AUTH_CONFIG_NAME="apihub-admin"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
AUTH_CONFIG_FULL_NAME="projects/${PROJECT_ID}/locations/${REGION}/authConfigs/${AUTH_CONFIG_NAME}"

echo "Configuring gcloud..."
gcloud config set project "$PROJECT_ID"
gcloud config set compute/region "$REGION"

echo "Enabling necessary APIs..."
gcloud services enable \
  apihub.googleapis.com \
  integrations.googleapis.com

echo "Creating Service Account $SERVICE_ACCOUNT_NAME..."
if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" > /dev/null 2>&1; then
  gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
    --display-name="Service Account for Azure APIM Integration"
else
  echo "Service Account $SERVICE_ACCOUNT_NAME already exists."
fi

echo "Granting roles to Service Account..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/apihub.admin"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/integrations.integrationEditor"

echo "Creating Application Integration Auth Config '$AUTH_CONFIG_NAME'..."

TOKEN=$(gcloud auth print-access-token)
AUTH_CONFIG_BASE_URL="https://integrations.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/authConfigs"
GET_AUTH_CONFIG_URL="${AUTH_CONFIG_BASE_URL}/${AUTH_CONFIG_NAME}"

GET_RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "$GET_AUTH_CONFIG_URL")

if [ "$GET_RESPONSE_CODE" == "200" ]; then
  echo "Auth Config '$AUTH_CONFIG_NAME' already exists."
else
  echo "Auth Config '$AUTH_CONFIG_NAME' not found (HTTP $GET_RESPONSE_CODE), creating..."
  AUTH_CONFIG_PAYLOAD=$(cat <<EOF
{
  "name": "${AUTH_CONFIG_FULL_NAME}",
  "displayName": "${AUTH_CONFIG_NAME}",
  "description": "Auth Config for API Hub Admin access using Service Account",
  "decryptedCredential": {
    "credentialType": "SERVICE_ACCOUNT",
    "serviceAccountCredentials": {
      "serviceAccount": "${SERVICE_ACCOUNT_EMAIL}",
      "scope": "https://www.googleapis.com/auth/cloud-platform"
    }
  },
  "visibility": "CLIENT_VISIBLE"
}
EOF
)
  # POST to the base URL, ID is in the payload's "name" field
  CREATE_RESPONSE=$(curl -X POST -s \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "${AUTH_CONFIG_PAYLOAD}" \
    "${AUTH_CONFIG_BASE_URL}")

  echo "Create Auth Config Response: $CREATE_RESPONSE"
  if echo "$CREATE_RESPONSE" | grep -q "error"; then
    echo "Error creating Auth Config '$AUTH_CONFIG_NAME'."
    exit 1
  else
    echo "Auth Config '$AUTH_CONFIG_NAME' created successfully."
  fi
fi

PLUGIN_ID="azure-apim-plugin"
INSTANCE_ID="azure-apim-plugin-instance"
TOKEN=$(gcloud auth print-access-token)

# --- 1. Ensure API Hub Plugin Definition Exists ---
PLUGIN_URL="https://apihub.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/plugins"
GET_PLUGIN_URL="${PLUGIN_URL}/${PLUGIN_ID}"

GET_RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "${GET_PLUGIN_URL}")

if [ "$GET_RESPONSE_CODE" == "200" ]; then
  echo "API Hub Plugin '$PLUGIN_ID' already exists in $REGION."
else
  echo "API Hub Plugin '$PLUGIN_ID' not found (HTTP $GET_RESPONSE_CODE), creating..."

  PLUGIN_PAYLOAD=$(cat <<EOF
{
  "display_name": "Azure APIM Plugin",
  "description": "A user-managed plugin to sync API data from Azure APIM instances into API hub using Application Integration.",
  "actions_config": [
    {
      "id": "sync-metadata",
      "display_name": "Sync Azure Metadata",
      "description": "Syncs API metadata from Azure APIM",
      "trigger_mode": "NON_API_HUB_MANAGED"
    }
  ],
  "plugin_category": "API_GATEWAY",
  "ownership_type": "USER_OWNED"
}
EOF
)

  CREATE_PLUGIN_URL="${PLUGIN_URL}?plugin_id=${PLUGIN_ID}"
  CREATE_RESPONSE=$(curl -X POST -s \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "${PLUGIN_PAYLOAD}" \
    "${CREATE_PLUGIN_URL}")

  echo "Create Plugin Response: $CREATE_RESPONSE"
  if echo "$CREATE_RESPONSE" | grep -q "error"; then
    echo "Error creating API Hub Plugin '$PLUGIN_ID'."
    exit 1
  else
    echo "API Hub Plugin '$PLUGIN_ID' created successfully."
  fi
fi

# --- 2. Create API Hub Plugin Instance ---
INSTANCE_BASE_URL="https://apihub.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/plugins/${PLUGIN_ID}/instances"
GET_INSTANCE_URL="${INSTANCE_BASE_URL}/${INSTANCE_ID}"

GET_RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "${GET_INSTANCE_URL}")

if [ "$GET_RESPONSE_CODE" == "200" ]; then
  echo "API Hub Plugin Instance '$INSTANCE_ID' already exists."
else
  echo "Creating API Hub Plugin Instance '$INSTANCE_ID'..."

  INSTANCE_PAYLOAD=$(cat <<EOF
{
  "display_name": "Azure APIM Sync instance",
  "actions": [
    {
      "action_id": "sync-metadata"
    }
  ]
}
EOF
)

  CREATE_INSTANCE_URL="${INSTANCE_BASE_URL}?plugin_instance_id=${INSTANCE_ID}"

  CREATE_RESPONSE=$(curl -X POST -s \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "${INSTANCE_PAYLOAD}" \
    "${CREATE_INSTANCE_URL}")

  echo "Create Instance Response: $CREATE_RESPONSE"
  if echo "$CREATE_RESPONSE" | grep -q "error"; then
    echo "Error creating API Hub Plugin Instance '$INSTANCE_ID'."
    exit 1
  else
    echo "API Hub Plugin Instance '$INSTANCE_ID' created successfully."
    echo "Instance Name: projects/${PROJECT_ID}/locations/${REGION}/plugins/${PLUGIN_ID}/instances/${INSTANCE_ID}"
  fi
fi

echo "API Hub Plugin and Instance setup complete for '$INSTANCE_ID'."

echo "GCP Setup Complete."
echo "PROJECT_ID=$PROJECT_ID"
echo "REGION=$REGION"
