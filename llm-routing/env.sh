#!/bin/bash

# Copyright © 2024-2025 Google LLC
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

# See the note about Vertex AI regions in the README
export VERTEXAI_REGION="VERTEXAI_REGION_TO_SET"
export VERTEXAI_PROJECT_ID="VERTEXAI_PROJECT_ID_TO_SET"

export HUGGINGFACE_TOKEN="HUGGINGFACE_TOKEN_TO_SET"
export MISTRAL_APIKEY="MISTRAL_APIKEY_TO_SET"

# modify these if you like
export SERVICE_ACCOUNT_NAME="llm-routing-svc-acct"
export GEMINI_MODEL_ID="gemini-2.5-flash"
