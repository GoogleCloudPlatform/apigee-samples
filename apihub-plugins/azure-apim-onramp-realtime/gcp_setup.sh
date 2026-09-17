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
# Google Cloud side (WIF pool/provider + service account + impersonation).
# Idempotent: reuses existing resources; handles WIF pool soft-delete.
# Auto-loads generated.env (from azure_setup.sh) + env.sh. Run from the plugin folder.
set -euo pipefail

[[ -f generated.env ]] && source generated.env
[[ -f env.sh ]] && source env.sh

: "${GCP_PROJECT:?}"; : "${GCP_PROJECT_NUMBER:?}"
: "${AZURE_TENANT_ID:?run azure_setup.sh first (produces generated.env)}"
: "${AZURE_APP_ID:?}"; : "${AZURE_MI_OBJECT_ID:?}"
POOL_ID="${POOL_ID:-apihub-azure-onramp-pool}"
PROVIDER_ID="${PROVIDER_ID:-azure-apim-oidc}"
SA_NAME="${SA_NAME:-apihub-azure-onramp-sa}"
SA_EMAIL="${SA_NAME}@${GCP_PROJECT}.iam.gserviceaccount.com"

gcloud config set project "$GCP_PROJECT" >/dev/null

echo "== [1/5] Enable APIs =="
gcloud services enable sts.googleapis.com iamcredentials.googleapis.com iam.googleapis.com apihub.googleapis.com

echo "== [2/5] Service account (create or reuse) =="
gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1 \
  || gcloud iam service-accounts create "$SA_NAME" --display-name="Azure APIM real-time on-ramp"
gcloud projects add-iam-policy-binding "$GCP_PROJECT" \
  --member="serviceAccount:${SA_EMAIL}" --role="roles/apihub.editor" --condition=None >/dev/null

echo "== [3/5] WIF pool (create/reuse; undelete if soft-deleted) =="
if gcloud iam workload-identity-pools describe "$POOL_ID" --location=global >/dev/null 2>&1; then
  STATE="$(gcloud iam workload-identity-pools describe "$POOL_ID" --location=global --format='value(state)')"
  [[ "$STATE" == "DELETED" ]] && gcloud iam workload-identity-pools undelete "$POOL_ID" --location=global
  echo "   pool exists ($STATE)"
else
  gcloud iam workload-identity-pools create "$POOL_ID" --location=global --display-name="Azure onramp pool"
fi

echo "== [4/5] OIDC provider (create or reuse) =="
if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
     --location=global --workload-identity-pool="$POOL_ID" >/dev/null 2>&1; then
  echo "   provider exists; skipping"
else
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --location=global --workload-identity-pool="$POOL_ID" \
    --issuer-uri="https://sts.windows.net/${AZURE_TENANT_ID}/" \
    --allowed-audiences="api://${AZURE_APP_ID}" \
    --attribute-mapping="google.subject=assertion.sub"
fi

echo "== [5/5] Impersonation binding (idempotent) =="
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principal://iam.googleapis.com/projects/${GCP_PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/subject/${AZURE_MI_OBJECT_ID}" >/dev/null

echo "DONE. WIF trust established. Create/update an API in APIM to test end-to-end."
