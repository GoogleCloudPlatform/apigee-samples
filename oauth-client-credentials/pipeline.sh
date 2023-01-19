#!/bin/sh
# Copyright 2022 Google LLC
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

set -e

SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"

proxyName="oauth-client-credentials"
developerEmail="apigee-samples@example.com"
appName="apigee-samples-app"
productName="apigee-samples-product"

rm -f "$SCRIPTPATH"/edge.json
cat <<EOF >> "$SCRIPTPATH/edge.json"
{
    "version": "1.0",
    "envConfig": {
        "$APIGEE_X_ENV": {
            "targetServers": [],
            "virtualHosts": [],
            "caches": [],
            "kvms": []
        }
    },
    "orgConfig": {
        "apiProducts": [
            {
                "name": "$productName",
                "approvalType": "auto",
                "attributes": [
                    {
                        "name": "access",
                        "value": "public"
                    }
                ],
                "description": "Used by apigee-samples/$proxyName",
                "displayName": "oauth-client-credentials-product",
                "environments": [
                    "$APIGEE_X_ENV"
                ],
                "operationGroup": {
                    "operationConfigs": [
                        {
                            "apiSource": "$proxyName",
                            "operations": [
                            {
                                "resource": "/**",
                                "methods": [
                                    "GET"
                                ]
                            }
                            ],
                            "quota": {}
                        }
                    ],
                    "operationConfigType": "proxy"
                }
            }
        ],
        "developers": [
            {
                "email": "$developerEmail",
                "firstName": "Apigee",
                "lastName": "Samples",
                "userName": "ApigeeSamplesDeveloper",
                "attributes": []
            }
        ],
        "developerApps": {
            "$developerEmail": [
                {
                    "name": "$appName",
                    "attributes": [],
                    "apiProducts": [
                        "$productName"
                    ],
                    "callbackUrl": "",
                    "scopes": []
                }
            ]
        }
    }
}
EOF

googleToken=$(gcloud auth print-access-token);

export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

# deploy Apigee artifacts: proxy, developer, app, product
sackmesser deploy --googleapi -n "$proxyName" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$googleToken" -h "$APIGEE_X_HOSTNAME" -d "$SCRIPTPATH"

# fetch newly created app
appId=$(sackmesser list --googleapi -t "$googleToken" "organizations/$APIGEE_X_ORG/developers/$developerEmail/apps/$appName" | jq -r '.appId')
appJson=$(sackmesser list --googleapi -t "$googleToken" "organizations/$APIGEE_X_ORG/apps/$appId" | jq '.credentials[0]')

# extract client id and secret from newly created app
APP_CLIENT_ID=$(echo "$appJson" | jq -r  '.consumerKey')
export APP_CLIENT_ID

APP_CLIENT_SECRET=$(echo "$appJson" | jq -r  '.consumerSecret')
export APP_CLIENT_SECRET

# var is expected by integration test (apickli)
export PROXY_URL="$APIGEE_X_HOSTNAME/apigee-samples/oauth-client-credentials"

# integration tests
npm install
npm run test

# clean up
if [ "$OAUTH_CLIENT_CREDENTIALS_CLEAN_UP" = "true" ]; then
  echo "Deleting app, developer, product..."
  sackmesser clean app "$appId" --googleapi -t "$googleToken" -o "$APIGEE_X_ORG" --quiet
  sackmesser clean developer "$developerEmail" --googleapi -t "$googleToken" -o "$APIGEE_X_ORG" --quiet
  sackmesser clean product "$productName" --googleapi -t "$googleToken" -o "$APIGEE_X_ORG" --quiet
  rm -f "$SCRIPTPATH"/edge.json

  echo "Deleting API proxy..."
  sackmesser clean proxy "$proxyName" --googleapi -t "$googleToken" -o "$APIGEE_X_ORG" --quiet
fi