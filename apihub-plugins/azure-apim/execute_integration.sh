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
set -e

if [ -z "$PROJECT_ID" ]; then
  echo "No PROJECT_ID variable set"
  exit
fi

if [ -z "$REGION" ]; then
  echo "No REGION variable set"
  exit
fi

if [ -z "$INTEGRATION_NAME" ]; then
  echo "No INTEGRATION_NAME variable set"
  exit
fi

if [ -z "$AZURE_CLIENT_ID" ]; then
  echo "No AZURE_CLIENT_ID variable set"
  exit
fi

if [ -z "$AZURE_CLIENT_SECRET" ]; then
  echo "No AZURE_CLIENT_SECRET variable set"
  exit
fi

if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
  echo "No AZURE_SUBSCRIPTION_ID variable set"
  exit
fi

if [ -z "$AZURE_TENANT_ID" ]; then
  echo "No AZURE_TENANT_ID variable set"
  exit
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
