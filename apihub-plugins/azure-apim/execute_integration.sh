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
read -p "Enter the Google Cloud Region: " REGION
read -p "Enter the Integration Name to execute: " INTEGRATION_NAME
read -p "Enter the AZURE_CLIENT_ID: " AZURE_CLIENT_ID
read -s -p "Enter the AZURE_CLIENT_SECRET: " AZURE_CLIENT_SECRET
echo
read -p "Enter the AZURE_SUBSCRIPTION_ID: " AZURE_SUBSCRIPTION_ID
read -p "Enter the AZURE_TENANT_ID: " AZURE_TENANT_ID

if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ] || [ -z "$INTEGRATION_NAME" ] || [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ] || [ -z "$AZURE_SUBSCRIPTION_ID" ] || [ -z "$AZURE_TENANT_ID" ]; then
  echo "Error: All parameters are required."
  exit 1
fi

# Get access token
TOKEN=$(gcloud auth print-access-token)

EXECUTE_URL="https://integrations.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/integrations/$INTEGRATION_NAME:execute"

echo "Executing Integration $INTEGRATION_NAME..."

curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "trigger_id": "api_trigger/azure_apim_sync_trigger",
    "inputParameters": {
      "in_client_id": { "stringValue": "'"$AZURE_CLIENT_ID"'" },
      "in_client_secret": { "stringValue": "'"$AZURE_CLIENT_SECRET"'" },
      "in_subscription_id": { "stringValue": "'"$AZURE_SUBSCRIPTION_ID"'" },
      "in_tenant_id": { "stringValue": "'"$AZURE_TENANT_ID"'" }
    }
  }' \
  "$EXECUTE_URL"

echo ""
echo "Execution triggered. Check the Application Integration logs in the Cloud Console for status."
