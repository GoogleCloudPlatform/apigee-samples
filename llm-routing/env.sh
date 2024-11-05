#!/bin/bash

# Copyright 2024 Google LLC
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
export APIGEE_ENV="APIGEE_ENV_TO_SET"
export APIGEE_HOST="APIGEE_HOST_TO_SET"
export SERVICE_ACCOUNT_NAME="llm-routing-svc-acct"

# Anthropic configuration
export ANTHROPIC_AI_REGION="ANTHROPIC_AI_REGION_TO_SET" # could be same as Apigee region
export ANTHROPIC_PROJECT_ID="ANTHROPIC_PROJECT_ID_TO_SET" # could be same as Apigee region

# Vertex AI configuration
export VERTEX_AI_REGION="VERTEX_AI_REGION_TO_SET"         # could be same as Apigee region
export VERTEX_AI_PROJECT_ID="VERTEX_AI_PROJECT_ID_TO_SET" # could be same as Apigee project
