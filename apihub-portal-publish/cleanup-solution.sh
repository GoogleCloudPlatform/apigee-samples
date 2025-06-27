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

echo "👉 Starting clean-up of resources..."

# delete Apigee API hub API
apigeecli apihub apis delete --id "apigee-sample-api" -o "$PROJECT_ID" -r "$APIHUB_REGION" -t "$(gcloud auth print-access-token)" --force

# delete Apigee API hub deployments
apigeecli apihub deployments delete -i "apigee-sample-unmanaged-v1-deployment" -o "$PROJECT_ID" -r "$APIHUB_REGION" -t "$(gcloud auth print-access-token)"

apigeecli apihub deployments delete -i "apigee-sample-managed-v1-deployment" -o "$PROJECT_ID" -r "$APIHUB_REGION" -t "$(gcloud auth print-access-token)"

# delete portal doc
CATALOG_ID=$(apigeecli apidocs list -s "$APIGEE_PORTAL_ID" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)" | jq --raw-output '.data[] | select(.apiProductName=="apihub-portal-product") | 
.id')
apigeecli apidocs delete -i "$CATALOG_ID" -s "$APIGEE_PORTAL_ID" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)"

# delete apigee product
apigeecli products delete -n "apihub-portal-product" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)"

# delete proxy
apigeecli apis undeploy -n "apihub-portal-publish" -e "$APIGEE_ENV" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)"
apigeecli apis delete -n "apihub-portal-publish" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)"

# delete proxy local file
rm apihub-portal-publish.zip

echo "👌 Clean-up of resources complete!"