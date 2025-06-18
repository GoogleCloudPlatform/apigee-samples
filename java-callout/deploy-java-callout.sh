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

if [ -z "$PROJECT" ]; then
  echo "No PROJECT variable set"
  exit
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit
fi

if [ -z "$APIGEE_HOST" ]; then
  echo "No APIGEE_HOST variable set"
  exit
fi

echo "This script downloads Apigee JAR files and installs them into the local Maven repo."

mkdir callout/lib
mkdir -p apiproxy/resources/java

curl "https://us-maven.pkg.dev/apigee-release/apigee-java-callout-dependencies/com/apigee/gateway/libraries/message-flow/1.0.0/message-flow-1.0.0.jar" -v -L -o callout/lib/message-flow-1.0.0.jar

mvn install:install-file \
  -Dfile=callout/lib/message-flow-1.0.0.jar \
  -DgroupId=com.apigee.gateway.libraries \
  -DartifactId=message-flow \
  -Dversion=1.0.0 \
  -Dpackaging=jar \
  -DgeneratePom=true

curl "https://us-maven.pkg.dev/apigee-release/apigee-java-callout-dependencies/com/apigee/infra/libraries/expressions/1.0.0/expressions-1.0.0.jar" -v -L -o callout/lib/expressions-1.0.0.jar

mvn install:install-file \
  -Dfile=callout/lib/expressions-1.0.0.jar \
  -DgroupId=com.apigee.infra.libraries \
  -DartifactId=expressions \
  -Dversion=1.0.0 \
  -Dpackaging=jar \
  -DgeneratePom=true

echo "Apigee JAR files have been installed into the local Maven repo."

cd callout || exit
echo "Compiling the custom jar file."

mvn clean package
echo "Custom jar file compilation complete."

cd ..

TOKEN=$(gcloud auth print-access-token)

echo "Installing dependencies"
npm install

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Running apigeelint"
npm run lint

echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee java-callout proxy..."
REV=$(apigeecli apis create bundle -f apiproxy -n java-callout --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)

apigeecli apis deploy --wait --name java-callout --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

# var is expected by integration test (apickli)
export PROXY_URL="$APIGEE_HOST/v1/samples/java-callout"

# integration tests
npm run test

echo " "
echo "All of the Apigee artifacts hav been successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo " "
echo "You can test your proxy using the following command:"
echo "curl -v GET https://$PROXY_URL/"
echo " "
