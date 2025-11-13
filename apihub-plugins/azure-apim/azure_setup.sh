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

if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
  echo "No AZURE_SUBSCRIPTION_ID variable set"
  exit
fi

if [ -z "$AZURE_TENANT_ID" ]; then
  echo "No AZURE_TENANT_ID variable set"
  exit
fi

if [ -z "$AZURE_APP_NAME" ]; then
  echo "No AZURE_APP_NAME variable set"
  exit
fi

if [ -z "$AZURE_APIM_RESOURCE_NAME" ]; then
  echo "No AZURE_APIM_RESOURCE_NAME variable set"
  exit
fi

if [ -z "$AZURE_RESOURCE_GROUP" ]; then
  echo "No AZURE_RESOURCE_GROUP variable set"
  exit
fi

echo "Logging in to Azure..."
az login

az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# if [ -z "$AZURE_TENANT_ID" ]; then
#   AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
#   echo "Inferred Azure Tenant ID: $AZURE_TENANT_ID"
# fi

echo "Creating Azure AD Application $AZURE_APP_NAME..."
APP_INFO=$(az ad app create --display-name "$AZURE_APP_NAME")
AZURE_CLIENT_ID=$(echo "$APP_INFO" | jq -r .appId)

if [ -z "$AZURE_CLIENT_ID" ] || [ "$AZURE_CLIENT_ID" == "null" ]; then
  echo "Error: Failed to create Azure AD App."
  exit 1
fi
echo "Azure AD App Client ID: $AZURE_CLIENT_ID"

echo "Creating Service Principal..."
az ad sp create --id "$AZURE_CLIENT_ID"

echo "Generating Client Secret..."
SECRET_INFO=$(az ad app credential reset --id "$AZURE_CLIENT_ID" --append)
AZURE_CLIENT_SECRET=$(echo "$SECRET_INFO" | jq -r .password)

if [ -z "$AZURE_CLIENT_SECRET" ] || [ "$AZURE_CLIENT_SECRET" == "null" ]; then
  echo "Error: Failed to generate Client Secret."
  exit 1
fi

echo "Granting Reader role to the App on APIM instance $AZURE_APIM_RESOURCE_NAME..."
APIM_RESOURCE_ID=$(az apim show --name "$AZURE_APIM_RESOURCE_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --query id -o tsv)

if [ -z "$APIM_RESOURCE_ID" ]; then
    echo "Error: Could not find APIM instance $AZURE_APIM_RESOURCE_NAME in resource group $AZURE_RESOURCE_GROUP."
    exit 1
fi

az role assignment create --assignee "$AZURE_CLIENT_ID" \
  --role "Reader" \
  --scope "$APIM_RESOURCE_ID"
echo "Granted 'Reader' role."

echo "Azure Setup Complete. Please note these values:"
echo "AZURE_CLIENT_ID=$AZURE_CLIENT_ID"
echo "AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET"
echo "AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID"
echo "AZURE_TENANT_ID=$AZURE_TENANT_ID"
echo "IMPORTANT: Save the AZURE_CLIENT_SECRET securely!"
