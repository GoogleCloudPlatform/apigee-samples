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

gcloud compute instances delete $VM_NAME --zone $ZONE --project $PROJECT_ID --quiet
apigeecli apis undeploy -e $APIGEE_ENV -n mtls-southbound-v1 -o $PROJECT_ID -t $(gcloud auth print-access-token)
apigeecli apis delete -n mtls-southbound-v1 -o $PROJECT_ID -t $(gcloud auth print-access-token)
apigeecli targetservers delete -n mtls-service -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)
apigeecli keystores delete -n mtls-keystore1 -o $PROJECT_ID -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)