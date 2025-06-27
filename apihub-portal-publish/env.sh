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

export PROJECT_ID="YOUR_PROJECT_ID" # the GCP project where apigee is provisioned
export REGION="europe-west1" # the region where Apigee is provisioned
export APIHUB_REGION="europe-west1" # the region where Apigee API hub is provisioned
export APIGEE_ENV="dev" # the name of your apigee environment, for example dev or eval
export APIGEE_HOST="YOUR_APIGEE_HOST" # the hostname of your apigee environment group
export APIGEE_PORTAL_URL="YOUR_PORTAL_URL" # the URL of your Apigee integrated portal
