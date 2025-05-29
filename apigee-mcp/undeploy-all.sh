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

# --- Helper Functions ---

# Function to undeploy all revisions of an API proxy from a specific environment
undeploy_all_revisions() {
  local proxy_name="$1"
  local org="$2"
  local env="$3"
  local token="$4"

  echo "INFO: Listing deployed revisions for proxy '${proxy_name}' in env '${env}'..."
  # Attempt to get revisions. Suppress stderr for listdeploy in case proxy or deployments don't exist.
  # jq will output nothing if .deployments is null or empty, or if .revision is not found.
  local revisions
  revisions=$(apigeecli envs deployments get --org "${org}" --env "${env}" --token "${token}" --disable-check | jq --arg proxy_name "$proxy_name" '.deployments[] | select(.apiProxy==$proxy_name).revision' -r)

  if [ -z "$revisions" ]; then
    echo "INFO: No deployed revisions found for proxy '${proxy_name}' in env '${env}', or proxy not deployed."
    return 0
  fi

  echo "INFO: Found deployed revisions for '${proxy_name}': ${revisions}"
  for rev in $revisions; do
    echo "INFO: Undeploying revision '${rev}' of proxy '${proxy_name}' from env '${env}'..."
    if ! apigeecli apis undeploy --name "${proxy_name}" --rev "${rev}" --org "${org}" --env "${env}" --token "${token}" --disable-check; then
      echo "WARNING: Failed to undeploy revision '${rev}' of proxy '${proxy_name}'. It might have already been undeployed or another issue occurred. Continuing..."
    else
      echo "INFO: Successfully undeployed revision '${rev}' of proxy '${proxy_name}'."
    fi
  done
}

# --- Variable Checks ---
echo "Performing environment variable checks for undeployment..."
REQUIRED_VARS=(
    "PROJECT"
    "REGION"
    "APIGEE_ENV"
    "APIGEE_HOST" # Though not directly used in all delete commands, kept for consistency
    "SA_EMAIL"    # Though not directly used in all delete commands, kept for consistency
)
ALL_VARS_SET=true
for var_name in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var_name}" ]; then
    echo "ERROR: No ${var_name} variable set. Please set it for the undeployment script."
    ALL_VARS_SET=false
  fi
done

if [ "$ALL_VARS_SET" = false ]; then
  echo "ERROR: One or more required environment variables are missing. Exiting."
  exit 1
fi
echo "All required global variables for undeployment are set."

if [ -z "$TOKEN" ]; then
  echo "INFO: No TOKEN variable set. Attempting to fetch from gcloud."
  TOKEN=$(gcloud auth print-access-token)
  if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to get gcloud access token. Please login or set the TOKEN variable."
    exit 1
  fi
  echo "INFO: Successfully fetched gcloud access token. This token will be used for the duration of the script."
  echo "INFO: If the script takes longer than the token's validity (typically 1 hour), you may need to re-run it with a fresh token."
fi

if ! command -v jq &> /dev/null; then
    echo "ERROR: jq command not found. Please ensure it is installed and in your PATH."
    exit 1
fi

echo "--------------------------------------------------"
echo "--- Starting Undeployment Process ---"
echo "--------------------------------------------------"
echo "This script will attempt to delete resources created by deploy-all.sh."
echo "Please ensure you have the necessary permissions for all operations."
echo "PROJECT: ${PROJECT}"
echo "REGION: ${REGION}"
echo "APIGEE_ENV: ${APIGEE_ENV}"
echo "--------------------------------------------------"

# --- Main Undeployment Script ---

echo "Installing apigeecli..."
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download/install apigeecli."
    exit 1
fi
export PATH=$PATH:$HOME/.apigeecli/bin
echo "apigeecli installed and PATH updated."

# 1. Cloud Run Service `crm-mcp-service`
echo "Attempting to delete Cloud Run service 'crm-mcp-service'..."
if ! gcloud run services delete "crm-mcp-service" \
    --platform="managed" \
    --region="${REGION}" \
    --quiet; then
    echo "WARNING: Failed to delete Cloud Run service 'crm-mcp-service'. It might not exist or another error occurred."
else
    echo "INFO: Cloud Run service 'crm-mcp-service' deleted or did not exist."
fi
echo "--------------------------------------------------"

# 3. Apigee Developer App `crm-consumer-app`
DEVELOPER_EMAIL="mcpconsumer@cymbal.com"
APP_NAME="crm-consumer-app"
echo "Attempting to delete Apigee Developer App '${APP_NAME}' for developer '${DEVELOPER_EMAIL}'..."
if ! apigeecli developers apps delete --email "${DEVELOPER_EMAIL}" --name "${APP_NAME}" --org "$PROJECT" --token "$TOKEN" --disable-check; then
    echo "WARNING: Failed to delete Apigee Developer App '${APP_NAME}'. It might not exist or an error occurred."
else
    echo "INFO: Apigee Developer App '${APP_NAME}' deleted."
fi
echo "--------------------------------------------------"

# 5. Apigee Products
echo "Attempting to delete Apigee Product 'crm-product'..."
if ! apigeecli products delete --name "crm-product" --org "$PROJECT" --token "$TOKEN" --disable-check; then
    echo "WARNING: Failed to delete Apigee Product 'crm-product'. It might not exist or an error occurred."
else
    echo "INFO: Apigee Product 'crm-product' deleted."
fi

echo "Attempting to delete Apigee Product 'mcp-product'..."
if ! apigeecli products delete --name "mcp-product" --org "$PROJECT" --token "$TOKEN" --disable-check; then
    echo "WARNING: Failed to delete Apigee Product 'mcp-product'. It might not exist or an error occurred."
else
    echo "INFO: Apigee Product 'mcp-product' deleted."
fi
echo "--------------------------------------------------"

# 4. Apigee Developer `consumer`
echo "Attempting to delete Apigee Developer '${DEVELOPER_EMAIL}'..."
if ! apigeecli developers delete --email "${DEVELOPER_EMAIL}" --org "$PROJECT" --token "$TOKEN" --disable-check; then
    echo "WARNING: Failed to delete Apigee Developer '${DEVELOPER_EMAIL}'. It might not exist or an error occurred (e.g., apps still associated if app deletion failed)."
else
    echo "INFO: Apigee Developer '${DEVELOPER_EMAIL}' deleted."
fi
echo "--------------------------------------------------"

# 5. Apigee API Proxy `crm-mcp-proxy`
echo "Attempting to undeploy and delete Apigee API Proxy 'crm-mcp-proxy'..."
undeploy_all_revisions "crm-mcp-proxy" "$PROJECT" "$APIGEE_ENV" "$TOKEN"
if ! apigeecli apis delete --name "crm-mcp-proxy" --org "$PROJECT" --token "$TOKEN" --disable-check; then
    echo "WARNING: Failed to delete Apigee API Proxy 'crm-mcp-proxy'. It might not exist or an error occurred during deletion."
else
    echo "INFO: Apigee API Proxy 'crm-mcp-proxy' undeployed (if previously deployed) and deleted (if existed)."
fi
echo "--------------------------------------------------"

# 6. Apigee API Proxy `customers-api`
echo "Attempting to undeploy and delete Apigee API Proxy 'customers-api'..."
undeploy_all_revisions "customers-api" "$PROJECT" "$APIGEE_ENV" "$TOKEN"
if ! apigeecli apis delete --name "customers-api" --org "$PROJECT" --token "$TOKEN" --disable-check; then
    echo "WARNING: Failed to delete Apigee API Proxy 'customers-api'. It might not exist or an error occurred."
else
    echo "INFO: Apigee API Proxy 'customers-api' undeployed (if previously deployed) and deleted (if existed)."
fi
echo "--------------------------------------------------"

# 7. Apigee API Proxy `mcp-spec-tools`
echo "Attempting to undeploy and delete Apigee API Proxy 'mcp-spec-tools'..."
undeploy_all_revisions "mcp-spec-tools" "$PROJECT" "$APIGEE_ENV" "$TOKEN"
if ! apigeecli apis delete --name "mcp-spec-tools" --org "$PROJECT" --token "$TOKEN" --disable-check; then
    echo "WARNING: Failed to delete Apigee API Proxy 'mcp-spec-tools'. It might not exist or an error occurred."
else
    echo "INFO: Apigee API Proxy 'mcp-spec-tools' undeployed (if previously deployed) and deleted (if existed)."
fi
echo "--------------------------------------------------"

# 8. Apigee Resource `oauth_configuration.properties`
RESOURCE_NAME="oauth_configuration"
RESOURCE_TYPE="properties"
echo "Attempting to delete Apigee Resource '${RESOURCE_NAME}' (type: ${RESOURCE_TYPE}) from env '${APIGEE_ENV}'..."
if ! apigeecli res delete --name "${RESOURCE_NAME}" --type "${RESOURCE_TYPE}" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --disable-check; then
    echo "WARNING: Failed to delete Apigee Resource '${RESOURCE_NAME}'. It might not exist or an error occurred."
else
    echo "INFO: Apigee Resource '${RESOURCE_NAME}' deleted."
fi
echo "--------------------------------------------------"

# 9. ApiHub Resources for `customers-api`
APIHUB_API_ID="customers-api"
APIHUB_API_VERSION="1_0_0"
APIHUB_SPEC_ID="customers-api" # This was the spec ID used in 'specs create -i customers-api'

echo "Attempting to delete ApiHub Spec '${APIHUB_SPEC_ID}' for API '${APIHUB_API_ID}', version '${APIHUB_API_VERSION}'..."
if ! apigeecli apihub apis versions specs delete --api-id "${APIHUB_API_ID}" -v "${APIHUB_API_VERSION}" -i "${APIHUB_SPEC_ID}" --org "$PROJECT" -r "$REGION" --token "$TOKEN"; then
    echo "WARNING: Failed to delete ApiHub Spec '${APIHUB_SPEC_ID}'. It might not exist or an error occurred."
else
    echo "INFO: ApiHub Spec '${APIHUB_SPEC_ID}' deleted."
fi

echo "Attempting to delete ApiHub Version '${APIHUB_API_VERSION}' for API '${APIHUB_API_ID}'..."
if ! apigeecli apihub apis versions delete --api-id "${APIHUB_API_ID}" -i "${APIHUB_API_VERSION}" --org "$PROJECT" -r "$REGION" --token "$TOKEN"; then
    echo "WARNING: Failed to delete ApiHub Version '${APIHUB_API_VERSION}'. It might not exist or an error occurred (e.g., spec still present if spec deletion failed)."
else
    echo "INFO: ApiHub Version '${APIHUB_API_VERSION}' deleted."
fi

echo "Attempting to delete ApiHub API '${APIHUB_API_ID}'..."
if ! apigeecli apihub apis delete -i "${APIHUB_API_ID}" --org "$PROJECT" -r "$REGION" --token "$TOKEN"; then
    echo "WARNING: Failed to delete ApiHub API '${APIHUB_API_ID}'. It might not exist or an error occurred (e.g., versions still present if version deletion failed)."
else
    echo "INFO: ApiHub API '${APIHUB_API_ID}' deleted."
fi
echo "--------------------------------------------------"

# 10. Cloud Run Stub Service for "customers"
echo "Determining name for Customers Stub Service..."
CUSTOMERS_STUB_SERVICE_NAME="customers-service" # Default name
if [ -n "$CUSTOMERS_IMAGE_NAME" ]; then
  echo "INFO: CUSTOMERS_IMAGE_NAME is set to '${CUSTOMERS_IMAGE_NAME}'. Using this as the service name."
  CUSTOMERS_STUB_SERVICE_NAME="${CUSTOMERS_IMAGE_NAME}"
else
  echo "INFO: CUSTOMERS_IMAGE_NAME is not set. Using default service name '${CUSTOMERS_STUB_SERVICE_NAME}'."
fi

echo "Attempting to delete Cloud Run service '${CUSTOMERS_STUB_SERVICE_NAME}' (Customers Stub)..."
if ! gcloud run services delete "${CUSTOMERS_STUB_SERVICE_NAME}" \
    --platform="managed" \
    --region="${REGION}" \
    --quiet; then
    echo "WARNING: Failed to delete Cloud Run service '${CUSTOMERS_STUB_SERVICE_NAME}'. It might not exist or another error occurred."
else
    echo "INFO: Cloud Run service '${CUSTOMERS_STUB_SERVICE_NAME}' deleted or did not exist."
fi
echo "--------------------------------------------------"

# 11. Local file cleanup
if [ -f "oauth_configuration.properties" ]; then
  echo "Deleting local file 'oauth_configuration.properties'..."
  if rm -f oauth_configuration.properties; then
    echo "INFO: Local file 'oauth_configuration.properties' deleted."
  else
    echo "WARNING: Failed to delete local file 'oauth_configuration.properties'."
  fi
else
  echo "INFO: Local file 'oauth_configuration.properties' not found, no need to delete."
fi
echo "--------------------------------------------------"

echo "--- Undeployment Process Complete ---"
echo "INFO: The script has attempted to delete all known resources."
echo "INFO: Please check the output for any warnings or errors."
echo "INFO: You may want to manually verify in the Google Cloud Console and Apigee UI that all resources have been removed as expected."
echo "INFO: This script does not remove the apigeecli tool itself. If you wish to remove it, you can delete the \$HOME/.apigeecli directory."
echo "--------------------------------------------------"
