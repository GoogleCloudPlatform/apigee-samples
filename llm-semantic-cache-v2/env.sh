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

export PROJECT="PROJECT_ID_TO_SET"
export REGION="REGION_TO_SET"
export MODEL_ID="MODEL_ID_TO_SET" # Example, gemini-2.5-flash
export EMBEDDINGS_MODEL_ID="EMBEDDINGS_MODEL_ID_TO_SET" # Example, text-embedding-005
export NEAREST_NEIGHBOR_DISTANCE="NEAREST_NEIGHBOR_DISTANCE_TO_SET" # Example, 0.95
export CACHE_ENTRY_TTL_SEC="CACHE_ENTRY_TTL_SEC_TO_SET" # Example, 60
export APIGEE_HOST="APIGEE_HOST_TO_SET"
export APIGEE_ENV="APIGEE_ENV_TO_SET"