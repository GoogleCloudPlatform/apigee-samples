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
PROJECT_NUMBER="$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")"
export PROJECT_NUMBER
export APIGEE_ENV="APIGEE_ENV_TO_SET"
export APIGEE_HOST="APIGEE_HOST_TO_SET"
export SERVICE_ACCOUNT_NAME="llm-cymbal-retail-agent"

export MODEL_ARMOR_REGION="MODEL_ARMOR_REGION_TO_SET"
export MODEL_ARMOR_TEMPLATE_ID="llm-governance-template" #use existing or create new template using this id

export APIGEE_APIHUB_PROJECT_ID="APIGEE_APIHUB_PROJECT_ID_TO_SET"
export APIGEE_APIHUB_REGION="APIGEE_APIHUB_REGION_TO_SET"

export VERTEXAI_REGION="VERTEXAI_REGION_TO_SET"
export VERTEXAI_PROJECT_ID="VERTEXAI_PROJECT_ID_TO_SET"
export MODEL_NAME="gemini-2.5-flash"

gcloud config set project $PROJECT_ID