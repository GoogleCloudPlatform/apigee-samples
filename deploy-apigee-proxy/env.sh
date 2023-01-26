#!/bin/sh
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
PROJECT_NUMBER="$(gcloud projects describe $PROJECT --format="value(projectNumber)")"
export PROJECT_NUMBER
export CLOUD_BUILD_SA="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"

gcloud config set project $PROJECT