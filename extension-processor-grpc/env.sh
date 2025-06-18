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

# User configurable values (edit these)

#This is your Google Cloud Project ID (the same project where you access Apigee)
export PROJECT_ID="<YOUR_GCP_PROJECT_ID>"

# This is the name of the Apigee Runtime instance you will use for this tutorial
export APIGEE_INSTANCE_NAME="<YOUR_APIGEE_INSTANCE_NAME>"

# If you don't have PSC-only subnet, please copy paste the below command and run it in cloudshell.
#  Ensure the region specified in the command (--region) is the same as your Apigee instance region
# (i.e., ${INSTANCE_LOCATION}).,
# and decide the range as per your requirement, ensuring it doesn't conflict with other subnet ranges.

# gcloud compute networks subnets create "$VPC_PSC_SUBNET_NAME" \
#   --network="${VPC_NETWORK_NAME}" \
#   --region="${INSTANCE_LOCATION}" \
#   --range="192.168.1.0/24" \
#   --purpose=PRIVATE_SERVICE_CONNECT \
#   --project "${PROJECT_ID}"

# This is the name of a PSC-only subnet in the same region as your Apigee Runtime instance
export VPC_PSC_SUBNET_NAME="<YOUR_SUBNET_NAME>"

# This is the name of the VPC hosting the PSC-only subnet (above)
export VPC_NETWORK_NAME="<YOUR_VPC_NAME>"
