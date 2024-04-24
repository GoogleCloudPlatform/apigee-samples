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

set -e
export PATH="$(pwd)/tools/apache-maven/bin:$PATH"


echo "*** Downloading Apigee Expressions jar file ***"
curl -s -O https://raw.githubusercontent.com/apigee/api-platform-samples/master/doc-samples/java-cookbook/lib/expressions-1.0.0.jar
echo ""
echo ""

echo "*** Installing Apigee Expressions jar file ***"
mvn -ntp install:install-file \
  -Dfile=expressions-1.0.0.jar \
  -DgroupId=com.apigee.edge \
  -DartifactId=expressions \
  -Dversion=1.0.0 \
  -Dpackaging=jar \
  -DgeneratePom=true

rm expressions-1.0.0.jar

echo ""
echo ""


echo "*** Downloading Apigee Message Flow jar file ***"
curl -s -O https://raw.githubusercontent.com/apigee/api-platform-samples/master/doc-samples/java-cookbook/lib/message-flow-1.0.0.jar
echo ""
echo ""

echo "*** Installing Apigee Message Flow jar file ***"
mvn -ntp install:install-file \
  -Dfile=message-flow-1.0.0.jar \
  -DgroupId=com.apigee.edge \
  -DartifactId=message-flow \
  -Dversion=1.0.0 \
  -Dpackaging=jar \
  -DgeneratePom=true

rm message-flow-1.0.0.jar 

rm -f ./target/*.jar
echo ""
echo ""

echo "*** Building Java callout Jar file ***"
mvn -ntp package
echo ""
echo ""


echo "*** Copying Java callout Jar file to apiproxy ***"
cp ./target/apigee-callout-protobuf-decoder.jar ../bundle/apiproxy/resources/java/