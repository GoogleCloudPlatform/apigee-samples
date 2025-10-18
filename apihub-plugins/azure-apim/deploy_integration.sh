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

TEMPLATE_FILE="azure_ip_template.json"
TEMP_OUTPUT_FILE="integration_temp.json"
FINAL_PAYLOAD_FILE="integration_payload.json"

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: $TEMPLATE_FILE not found."
  exit 1
fi

echo "Replacing placeholders in $TEMPLATE_FILE..."
cp $TEMPLATE_FILE $TEMP_OUTPUT_FILE

# Replace placeholders. We need to escape the $ in the search pattern.
sed -i \
  -e "s/\\\$PROJECT_ID\\\$/${PROJECT_ID}/g" \
  -e "s/\\\$LOCATION_ID\\\$/${REGION}/g" \
  -e "s/\\\$INTEGRATION_NAME\\\$/${INTEGRATION_NAME}/g" \
  $TEMP_OUTPUT_FILE

echo "Checking for any remaining placeholders..."
if grep -E "\$(PROJECT_ID|LOCATION_ID|INTEGRATION_NAME)\$" $TEMP_OUTPUT_FILE; then
   echo "Warning: Some placeholders were NOT replaced! Check the lines above."
   exit 1
else
   echo "Placeholder replacement appears successful."
fi

# Prepare the content for the API call
jq -n --rawfile content "$TEMP_OUTPUT_FILE" '{"content": $content}' > $FINAL_PAYLOAD_FILE

echo "Deploying Integration $INTEGRATION_NAME to $PROJECT_ID in $REGION..."

# Get access token
TOKEN=$(gcloud auth print-access-token)

# API URL for uploading a new integration version
UPLOAD_URL="https://integrations.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/integrations/$INTEGRATION_NAME/versions:upload"

echo "Uploading new integration version..."
UPLOAD_RESPONSE=$(curl -X POST -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary "@$FINAL_PAYLOAD_FILE" \
  "$UPLOAD_URL")

# Uncomment to debug the upload failures of the integration.
# echo "Upload Response: $UPLOAD_RESPONSE"

# Clean up temporary files
rm $TEMP_OUTPUT_FILE
rm $FINAL_PAYLOAD_FILE

# Extract version ID from the response
VERSION_ID=$(echo "$UPLOAD_RESPONSE" | jq -r .integrationVersion.name | sed 's#.*/versions/##')

if [ -z "$VERSION_ID" ] || [ "$VERSION_ID" == "null" ]; then
    echo "Error: Failed to upload integration version. Check the response above."
    echo "Please ensure an integration with name '$INTEGRATION_NAME' exists in $REGION. You might need to create it manually in the console first."
    exit 1
fi

PUBLISH_URL="https://integrations.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/integrations/$INTEGRATION_NAME/versions/$VERSION_ID:publish"
echo "Publishing integration version $VERSION_ID..."
PUBLISH_RESPONSE=$(curl -X POST -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$PUBLISH_URL")

echo "Publish Response: $PUBLISH_RESPONSE"
echo "Integration Deployment Complete: $INTEGRATION_NAME"
