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

export PROJECT_ID="<GCP_PROJECT_ID>"
export REGION="<GCP_REGION>"
export INTEGRATION_NAME="azure-apim-plugin"
export SERVICE_ACCOUNT_NAME="azure-apim-integration-sa"
export AUTH_CONFIG_NAME="apihub-admin"

export AZURE_SUBSCRIPTION_ID="<AZURE_SUBSCRIPTION_ID>"
export AZURE_TENANT_ID="<AZURE_TENANT_ID>"
export AZURE_RESOURCE_GROUP="<AZURE_RESOURCE_GROUP>"
export AZURE_APP_NAME="<AZURE_APP_NAME>"
export AZURE_APIM_RESOURCE_NAME="<AZURE_APIM_RESOURCE_NAME>"

export AZURE_CLIENT_ID="<AZURE_CLIENT_ID>"
export AZURE_CLIENT_SECRET="<AZURE_CLIENT_SECRET>"