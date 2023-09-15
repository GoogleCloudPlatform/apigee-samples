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

if [ -z "$PROJECT" ]; then
	echo "No PROJECT variable set"
	exit
fi

if [ -z "$APIGEE_ENV" ]; then
	echo "No APIGEE_ENV variable set"
	exit
fi

TOKEN=$(gcloud auth print-access-token)

mvn -ntp clean process-resources -Pdev -Denv="$APIGEE_ENV" -Dorg="$PROJECT" -Dbearer="$TOKEN"

echo "Deleting API Developer Apps"
mvn -ntp apigee-config:apps -Pdev -Denv="$APIGEE_ENV" -Dorg="$PROJECT" -Dbearer="$TOKEN" -Doptions="delete"
echo "Deleting Developer"
mvn -ntp apigee-config:developers -Pdev -Denv="$APIGEE_ENV" -Dorg="$PROJECT" -Dbearer="$TOKEN" -Doptions="delete"
echo "Deleting API Products"
mvn -ntp apigee-config:apiproducts -Pdev -Denv="$APIGEE_ENV" -Dorg="$PROJECT" -Dbearer="$TOKEN" -Doptions="delete"
echo "Deleting Target servers"
mvn -ntp apigee-config:targetservers -Pdev -Denv="$APIGEE_ENV" -Dorg="$PROJECT" -Dbearer="$TOKEN" -Doptions="delete"
echo "Deleting KeyValueMaps"
mvn -ntp apigee-config:keyvaluemaps -Pdev -Denv="$APIGEE_ENV" -Dorg="$PROJECT" -Dbearer="$TOKEN" -Doptions="delete"
