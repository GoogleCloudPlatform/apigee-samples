#!/bin/bash

# Copyright 2023 Google LLC
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

export PROJECT="<GCP_PROJECT_ID>"
export APIGEE_HOST="<APIGEE_DOMAIN_NAME>"
export APIGEE_ENV="<APIGEE_ENVIRONMENT_NAME>"
export CLOUD_RUN_SERVICE_URL="<GRPC_CLOUD_RUN_SERVICE_URL>"
export ENV_GROUP_NAME="<YOUR_ENV_GROUP_NAME>"
export ENV_GROUP_HOSTNAME_GRPC="<YOUR_GRPC_DOMAIN_NAME>"
export GRPC_TARGET_SERVER_NAME=grpc-server

gcloud config set project $PROJECT