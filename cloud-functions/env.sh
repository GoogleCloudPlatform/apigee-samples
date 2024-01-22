#!/bin/bash

# Copyright 2023-2024 Google LLC
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

# For Apigee, set the GCP project, the name of the environment,
# and the hostname at which your API proxies can be reached.
export APIGEE_PROJECT="<GCP_PROJECT_ID>"
export APIGEE_ENV="<APIGEE_ENVIRONMENT_NAME>"
export APIGEE_HOST="<APIGEE_DOMAIN_NAME>"

# For Cloud Functions, specify the region, such as us-west1, us-east4, etc.,
# and the Project (may be the same as for Apigee)
export CLOUD_FUNCTIONS_REGION="<REGION>"
export CLOUD_FUNCTIONS_PROJECT="<GCP_PROJECT_ID>"
export CLOUD_FUNCTION_NAME="apigee-sample-hello"
