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

export PROJECT="<PROJECT_ID_TO_SET>"
export REGION="<REGION_TO_SET>"           # e.g., us-central1
export APIGEE_ENV="<APIGEE_ENV_TO_SET>"   # e.g., eval
export APIGEE_HOST="<APIGEE_HOST_TO_SET>" # e.g., your-org-eval.apigee.net
export SA_EMAIL="<SA_EMAIL_TO_SET>"       # e.g., apigee-runtime-sa@<PROJECT_ID_TO_SET>.iam.gserviceaccount.com

echo "Environment variables configured. Ensure values above are correctly set."
echo "PROJECT: $PROJECT"
echo "REGION: $REGION"
echo "APIGEE_ENV: $APIGEE_ENV"
echo "APIGEE_HOST: $APIGEE_HOST"
echo "SA_EMAIL: $SA_EMAIL"
