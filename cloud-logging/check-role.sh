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

source ./lib/utils.sh

check_shell_variables

# shellcheck disable=SC2002
gwho=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

printf "Google Cloud identity: %s\n\n" "$gwho"

gcloud projects get-iam-policy "$PROJECT" \
  --flatten="bindings[].members" \
  --format='table(bindings.role)' \
  --filter="bindings.members:user:$gwho"
