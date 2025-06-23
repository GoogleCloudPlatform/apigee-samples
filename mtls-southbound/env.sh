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

export PROJECT_ID="YOUR_PROJECT_ID" # the GCP project where apigee is running
export REGION="europe-west1" # the region where apigee is running
export APIGEE_ENV="dev" # the name of your apigee environment, for example dev or eval
export APIGEE_HOST="YOUR_APIGEE_HOST" # the hostname of your apigee environment group
export ZONE="europe-west1-c" # the zone where the test mtls southbound service should be deployed
export VM_NAME="mtls-vm1" # the name of the VM, can be anything
export VM_IP="YOUR_VM_IP_ADDRESS" # this will be filled in automatically by the deploy script

