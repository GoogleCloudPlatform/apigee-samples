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

# env.sh — fill in every <PLACEHOLDER>, then: source env.sh
# RG + APIM + API Hub instance are your existing resources; the scripts create everything else.

# ---- Azure ----
export AZURE_SUBSCRIPTION_ID="<AZURE_SUBSCRIPTION_ID>"
export RESOURCE_GROUP="<RESOURCE_GROUP>"          # the RG that already holds your APIM
export APIM_NAME="<APIM_SERVICE>"

# ---- Google Cloud ----
export GCP_PROJECT="<GCP_PROJECT>"                # API Hub host project
export GCP_PROJECT_NUMBER="<PROJECT_NUMBER>"
export APIHUB_LOCATION="<APIHUB_REGION>"          # e.g. europe-west1
export INSTANCE_ID="<PLUGIN_INSTANCE_ID>"        # existing system-azure-apim instance id
export APIHUB_HOST="https://apihub.googleapis.com"

# ---- optional ----
# export ENABLE_APP_INSIGHTS=true              # optional: function logs via Application Insights (default: off)
# export APP_ID=<APP_ID>                        # ONLY if an admin pre-created the App Registration for you
# export POOL_ID=apihub-azure-onramp-pool
# export PROVIDER_ID=azure-apim-oidc
# export SA_NAME=apihub-azure-onramp-sa
# export TAGS='{"env":"dev","owner":"you"}'
