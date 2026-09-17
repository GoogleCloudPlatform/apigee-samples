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
# Tear down everything the sample created. Ignores missing resources.
# Run from the plugin folder, after: source env.sh
set -uo pipefail
if [[ -f generated.env ]]; then source generated.env || true; fi

: "${RESOURCE_GROUP:?}"; : "${APIM_NAME:?}"
: "${GCP_PROJECT:?}"; : "${GCP_PROJECT_NUMBER:?}"
POOL_ID="${POOL_ID:-apihub-azure-onramp-pool}"
PROVIDER_ID="${PROVIDER_ID:-azure-apim-oidc}"
SA_NAME="${SA_NAME:-apihub-azure-onramp-sa}"
SA_EMAIL="${SA_NAME}@${GCP_PROJECT}.iam.gserviceaccount.com"

APIM_ID="$(az apim show -n "$APIM_NAME" -g "$RESOURCE_GROUP" --query id -o tsv 2>/dev/null || true)"

echo "== Azure: Event Grid subscription =="
if [[ -n "$APIM_ID" ]]; then
  az eventgrid event-subscription delete --name apihub-onramp-sync --source-resource-id "$APIM_ID" 2>/dev/null || true
fi

echo "== Azure: Function / plan / identity / App Insights / Log Analytics / storage =="
az functionapp delete -g "$RESOURCE_GROUP" -n func-apihub-onramp 2>/dev/null || true
az appservice plan delete -g "$RESOURCE_GROUP" -n plan-apihub-onramp --yes 2>/dev/null || true
az identity delete -g "$RESOURCE_GROUP" -n id-apihub-onramp 2>/dev/null || true
az monitor app-insights component delete -g "$RESOURCE_GROUP" --app appi-apihub-onramp 2>/dev/null || true
az monitor log-analytics workspace delete -g "$RESOURCE_GROUP" -n law-apihub-onramp --yes 2>/dev/null || true
for s in $(az storage account list -g "$RESOURCE_GROUP" --query "[?starts_with(name,'stapihubonramp')].name" -o tsv 2>/dev/null); do
  az storage account delete -g "$RESOURCE_GROUP" -n "$s" --yes 2>/dev/null || true
done

echo "== Azure: App Registration =="
if [[ -n "${AZURE_APP_ID:-}" ]]; then
  az ad app delete --id "$AZURE_APP_ID" 2>/dev/null || true
else
  AID="$(az ad app list --filter "displayName eq 'apihub-onramp-wif'" --query '[0].appId' -o tsv 2>/dev/null || true)"
  if [[ -n "$AID" && "$AID" != "None" ]]; then
    az ad app delete --id "$AID" 2>/dev/null || true
  fi
fi
# APIM system identity is left enabled (harmless). To remove:
# [[ -n "$APIM_ID" ]] && az resource update --ids "$APIM_ID" --set identity.type=None -o none || true

echo "== GCP: provider / pool / service account =="
gcloud iam workload-identity-pools providers delete "$PROVIDER_ID" \
  --location=global --workload-identity-pool="$POOL_ID" --quiet 2>/dev/null || true
gcloud iam workload-identity-pools delete "$POOL_ID" --location=global --quiet 2>/dev/null || true
gcloud iam service-accounts delete "$SA_EMAIL" --quiet 2>/dev/null || true

echo "DONE. (API Hub plugin instance left intact - delete manually only if it was created just for this test.)"
