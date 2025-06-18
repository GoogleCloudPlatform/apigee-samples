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

export PROJECT_ID=        # project/org where apigee is hosted
export APIGEE_HOST=       # e.g. api.mydomain.com
export APIGEE_ENV=        # e.g.dev or prod
export MICROSERVICE_PATH= # add your own. Or use https://httpbin.org/get for experimentation
export LEGACY_PATH=       # add your own. Or use https://mocktarget.apigee.net for experimentation

gcloud config set project "$PROJECT_ID"
