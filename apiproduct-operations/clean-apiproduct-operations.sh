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

PROXY_NAME=apiproduct-operations
OAUTH_CC_PROXY_NAME=apiproduct-operations-oauth2

delete_product() {
	local product_name=$1
	if apigeecli products get --name "${product_name}" --org "$PROJECT" --token "$TOKEN" --disable-check >>/dev/null 2>&1; then
		printf "Deleting API Product %s\n" "${product_name}"
		apigeecli products delete --name "${product_name}" --org "$PROJECT" --token "$TOKEN" --disable-check
	else
		printf "  The apiproduct %s does not exist.\n" "${product_name}"
	fi
}

delete_app() {
	local developer_id=$1
	local app_name=$2
	printf "Checking Developer App %s\n" "${app_name}"
	local NUM_APPS
	NUM_APPS=$(apigeecli apps get --name "${app_name}" --org "$PROJECT" --token "$TOKEN" --disable-check | jq -r .'| length')
	if [[ $NUM_APPS -eq 1 ]]; then
		printf "Deleting Developer App %s\n" "${app_name}"
		apigeecli apps delete --id "${developer_id}" --name "${app_name}" --org "$PROJECT" --token "$TOKEN"
	else
		printf "  The app %s does not exist for developer %s.\n" "${app_name}" "${developer_id}"
	fi
}

delete_developer() {
	local developer_email=$1
	if apigeecli developers get --email "${developer_email}" --org "$PROJECT" --token "$TOKEN" --disable-check >>/dev/null 2>&1; then
		apigeecli developers delete --email "${developer_email}" --org "$PROJECT" --token "$TOKEN" --disable-check
	else
		printf "  The developer %s does not exist.\n" "${developer_email}"
	fi
}

delete_apiproxy() {
	local proxy_name=$1
	printf "Checking Proxy %s\n" "${proxy_name}"
	if apigeecli apis get --name "$proxy_name" --org "$PROJECT" --token "$TOKEN" --disable-check >/dev/null 2>&1; then
		OUTFILE=$(mktemp /tmp/apigee-samples.apigeecli.out.XXXXXX)
		if apigeecli apis listdeploy --name "$proxy_name" --org "$PROJECT" --token "$TOKEN" --disable-check >$OUTFILE 2>&1; then
			NUM_DEPLOYS=$(jq -r '.deployments | length' "$OUTFILE")
			if [[ $NUM_DEPLOYS -ne 0 ]]; then
				echo "Undeploying ${proxy_name}"
				for ((i = 0; i < NUM_DEPLOYS; i++)); do
					ENVNAME=$(jq -r ".deployments[$i].environment" "$OUTFILE")
					REV=$(jq -r ".deployments[$i].revision" "$OUTFILE")
					apigeecli apis undeploy --name "${proxy_name}" --env "$ENVNAME" --rev "$REV" --org "$PROJECT" --token "$TOKEN" --disable-check
				done
			else
				printf "  There are no deployments of %s to remove.\n" "${proxy_name}"
			fi
		fi
		[[ -f "$OUTFILE" ]] && rm "$OUTFILE"

		echo "Deleting proxy ${proxy_name}"
		apigeecli apis delete --name "${proxy_name}" --org "$PROJECT" --token "$TOKEN" --disable-check

	else
		printf "  The proxy %s does not exist.\n" "${proxy_name}"
	fi
}

[[ -z "$PROJECT" ]] && echo "No PROJECT variable set" && exit 1
[[ -z "$APIGEE_ENV" ]] && echo "No APIGEE_ENV variable set" && exit 1
[[ -z "$APIGEE_HOST" ]] && echo "No APIGEE_HOST variable set" && exit 1

TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

DEVELOPER_EMAIL="${PROXY_NAME}-apigeesamples@acme.com"
printf "Checking Developer %s\n" ${DEVELOPER_EMAIL}
if apigeecli developers get --email ${DEVELOPER_EMAIL} --org "$PROJECT" --token "$TOKEN" --disable-check >>/dev/null 2>&1; then
	echo "Checking Developer Apps"
	DEVELOPER_ID=$(apigeecli developers get --email ${DEVELOPER_EMAIL} --org "$PROJECT" --token "$TOKEN" --disable-check | jq -r .'developerId')
	for apptype in "viewer" "creator" "admin"; do
		delete_app "$DEVELOPER_ID" "apiproduct-operations-${apptype}-app"
	done

	echo "Deleting Developer"
	delete_developer ${DEVELOPER_EMAIL}
else
	printf "  The developer %s does not exist.\n" ${DEVELOPER_EMAIL}
fi

echo "Checking API Products"
for apptype in "viewer" "creator" "admin"; do
	delete_product "apiproduct-operations-${apptype}"
done

delete_apiproxy ${PROXY_NAME}
delete_apiproxy ${OAUTH_CC_PROXY_NAME}

echo " "
echo "All the Apigee artifacts should have been removed."
echo " "
