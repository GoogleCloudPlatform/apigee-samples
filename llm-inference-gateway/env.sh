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

export PROJECT_ID="PROJECT_ID_TO_SET"
export APIGEE_ORG=$PROJECT_ID
export APIGEE_ENV="APIGEE_ENV_TO_SET" #apim-op-env
export NETWORK="NETWORK_TO_SET" #default
export SUBNET="SUBNET_TO_SET" #default
export REGION="REGION_TO_SET" #us-central1. Make sure this region matches with your Apigee region
export APIGEE_REGION=$REGION
export ZONE="ZONE_TO_SET" #us-central1-a
export CLUSTER_NAME="CLUSTER_NAME_TO_SET" #infgw-cluster
export HF_TOKEN="HF_TOKEN_TO_SET"

gcloud config set project "$PROJECT_ID"