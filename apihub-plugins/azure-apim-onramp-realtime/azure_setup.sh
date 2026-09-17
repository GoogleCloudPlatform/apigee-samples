#!/usr/bin/env bash

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
# Azure side of the Azure APIM -> API Hub real-time on-ramp.
# Idempotent: re-running reuses existing resources and never hard-fails on "already exists".
# Run from the plugin folder, after: source env.sh
set -euo pipefail

# ---------- config (from env.sh) ----------
: "${AZURE_SUBSCRIPTION_ID:?set it in env.sh}"
: "${RESOURCE_GROUP:?}"; : "${APIM_NAME:?}"
: "${GCP_PROJECT:?}"; : "${GCP_PROJECT_NUMBER:?}"; : "${APIHUB_LOCATION:?}"
: "${INSTANCE_ID:?}"; : "${APIHUB_HOST:?}"
DEPLOYMENT_TYPE_ID="${DEPLOYMENT_TYPE_ID:-azure-apim}"
POOL_ID="${POOL_ID:-apihub-azure-onramp-pool}"
PROVIDER_ID="${PROVIDER_ID:-azure-apim-oidc}"
SA_NAME="${SA_NAME:-apihub-azure-onramp-sa}"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-apihub-onramp-wif}"
ENABLE_APP_INSIGHTS="${ENABLE_APP_INSIGHTS:-false}"   # optional: function logs
TAGS="${TAGS:-{}}"

az account set --subscription "$AZURE_SUBSCRIPTION_ID"
TENANT_ID="$(az account show --query tenantId -o tsv)"

echo "== [1/8] Register resource providers (idempotent) =="
for p in Microsoft.EventGrid Microsoft.Web Microsoft.Storage Microsoft.ManagedIdentity; do
  az provider register -n "$p" --wait >/dev/null || echo "  (could not register $p - may need an admin; continuing)"
done
if [[ "$ENABLE_APP_INSIGHTS" == "true" ]]; then
  az provider register -n microsoft.insights --wait >/dev/null || true
fi

echo "== [2/8] Resolve APIM (id + region) =="
APIM_ID="$(az apim show -n "$APIM_NAME" -g "$RESOURCE_GROUP" --query id -o tsv)"
AZLOC="$(az apim show -n "$APIM_NAME" -g "$RESOURCE_GROUP" --query location -o tsv | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
echo "   APIM_ID=$APIM_ID   region=$AZLOC"

echo "== [3/8] App Registration (create or reuse) =="
if [[ -n "${APP_ID:-}" ]]; then
  echo "   using APP_ID from env: $APP_ID"
else
  APP_ID="$(az ad app list --filter "displayName eq '$APP_DISPLAY_NAME'" --query '[0].appId' -o tsv 2>/dev/null || true)"
  if [[ -z "$APP_ID" || "$APP_ID" == "None" ]]; then
    if ! APP_ID="$(az ad app create --display-name "$APP_DISPLAY_NAME" --sign-in-audience AzureADMyOrg --query appId -o tsv 2>/tmp/aderr)"; then
      echo "ERROR: cannot create the App Registration:"; sed 's/^/   /' /tmp/aderr
      echo "   -> App registration is enabled by default; if your tenant disabled it, get 'Application Developer'"
      echo "      or have an admin create the app and set APP_ID in env.sh, then re-run."
      exit 1
    fi
  fi
fi
az ad sp create --id "$APP_ID" >/dev/null 2>&1 || true
az ad app update --id "$APP_ID" --identifier-uris "api://$APP_ID"
echo "   APP_ID=$APP_ID"

echo "== [4/8] Deploy infra (Bicep; idempotent) =="
az deployment group create -g "$RESOURCE_GROUP" -f main.bicep -p \
  apimName="$APIM_NAME" location="$AZLOC" appId="$APP_ID" tags="$TAGS" \
  enableAppInsights="$ENABLE_APP_INSIGHTS" \
  gcpProject="$GCP_PROJECT" projectNumber="$GCP_PROJECT_NUMBER" \
  gcpLocation="$APIHUB_LOCATION" instanceId="$INSTANCE_ID" \
  apihubHost="$APIHUB_HOST" deploymentTypeId="$DEPLOYMENT_TYPE_ID" \
  poolId="$POOL_ID" providerId="$PROVIDER_ID" saName="$SA_NAME" -o none
O="$(az deployment group show -g "$RESOURCE_GROUP" -n main --query properties.outputs)"
FUNC="$(echo "$O" | jq -r .functionAppName.value)"
MI_OID="$(echo "$O" | jq -r .uamiPrincipalId.value)"
echo "   FUNC=$FUNC   MI_OID=$MI_OID"

echo "== [5/8] Publish the function (writes local.settings.json) =="
cat > local.settings.json <<'JSON'
{ "IsEncrypted": false, "Values": { "FUNCTIONS_WORKER_RUNTIME": "node", "AzureWebJobsStorage": "" } }
JSON
npm install
func azure functionapp publish "$FUNC" || func azure functionapp publish "$FUNC" --javascript

echo "== [6/8] Enable APIM system-assigned identity (idempotent; needed for Event Grid) =="
az resource update --ids "$APIM_ID" --set identity.type=SystemAssigned -o none

echo "== [7/8] Event Grid subscription APIM -> function (create or reuse) =="
if az eventgrid event-subscription show --name apihub-onramp-sync --source-resource-id "$APIM_ID" >/dev/null 2>&1; then
  echo "   subscription already exists; skipping"
else
  FUNC_ID="$(az functionapp show -n "$FUNC" -g "$RESOURCE_GROUP" --query id -o tsv)"
  az eventgrid event-subscription create --name apihub-onramp-sync \
    --source-resource-id "$APIM_ID" --endpoint-type azurefunction \
    --endpoint "${FUNC_ID}/functions/onrampApimSync" \
    --included-event-types Microsoft.ApiManagement.APICreated \
       Microsoft.ApiManagement.APIUpdated Microsoft.ApiManagement.APIDeleted
fi

echo "== [8/8] Write generated.env for the GCP step =="
cat > generated.env <<EOF
export AZURE_TENANT_ID=$TENANT_ID
export AZURE_APP_ID=$APP_ID
export AZURE_MI_OBJECT_ID=$MI_OID
EOF
echo "DONE. Next: ./gcp_setup.sh  (auto-loads generated.env)"
