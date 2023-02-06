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
export APIGEE_ENV="<APIGEE_ENVIRONMENT_NAME>"
export JWKS_URI="<IDP_PROVIDED_JWKS_ENDPOINT>"
export TOKEN_ISSUER="<IDP_PROVIDED_TOKEN_ISSUER_ID>"
export TOKEN_AUDIENCE="<IDP_PROVIDED_TOKEN_AUDIENCE>"
export TOKEN_CLIENT_ID_CLAIM="<CLIENT_IDENTIFIER_CLAIM_NAME>"
export IDP_APP_CLIENT_ID="<IDP_PROVIDED_APP_CLIENT_ID>"
export IDP_APP_CLIENT_SECRET="<IDP_PROVIDED_APP_CLIENT_SECRET>"

gcloud config set project $PROJECT