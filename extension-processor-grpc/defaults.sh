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

# Default values (DO NOT EDIT THESE BELOW)

# Prefixes
export PREFIX="apigee-sample-extproc"
export APIGEE_PREFIX="extproc"

# Load Balancer Config
export IP_NAME="${PREFIX}-lb-frontend-ip"
export CERT_NAME="${PREFIX}-lb-cert"
export URL_MAP_NAME="${PREFIX}-lb"
export TARGET_PROXY_NAME="${PREFIX}-lb-tgt-proxy"
export FORWARDING_RULE_NAME="${PREFIX}-lb-fwd-rule"
export SERVICE_NEG_NAME="${PREFIX}-neg-grpc"
export SERVICE_BACKEND_SERVICE_NAME="${PREFIX}-lb-be-svc"

# Apigee Config
export APIGEE_ORG="${PROJECT_ID}"
export ENV_NAME="${APIGEE_PREFIX}-env"
export GROUP_NAME="${APIGEE_PREFIX}-group"
export PROXY_NAME="${APIGEE_PREFIX}-proxy"
export PRODUCT_NAME="${APIGEE_PREFIX}-product"
export DEVELOPER_NAME="${APIGEE_PREFIX}-grpc-user"
export DEVELOPER_APP_NAME="${APIGEE_PREFIX}-grpc-app"
export PROXY_BUNDLE_DIR="bundle/apiproxy"

# Service Extension Config
export SERVICE_EXTENSION_NAME="${PREFIX}-callout-extension"
export RUNTIME_NEG_NAME="${PREFIX}-neg-runtime"
export RUNTIME_BACKEND_SERVICE_NAME="${PREFIX}-be-svc-runtime"

# Cloud Run Config
export CLOUD_RUN_NAME="${PREFIX}-grpc-backend"
export CLOUD_RUN_SERVICE_ACCOUNT_NAME="${PREFIX}-sa1"
