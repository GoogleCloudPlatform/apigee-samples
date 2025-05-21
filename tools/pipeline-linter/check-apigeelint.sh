#!/bin/bash
# Copyright 2020 Google LLC
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

# Ensures that all sub-projects in this repository are linted
# and also check if the basepath convention is followed
# using apigeelint.

set -e

#add any proxy that needs to be excluded. Needs review before adding any exclusions
proxyExclusions=(
  'grpc'
)

#add any sharedflow that needs to be excluded. Needs review before adding any exclusions
sfExclusions=(
  ' '
)

echo "Running using Apigeelint version - $(apigeelint --version)"
echo ""

# For API Proxies
for proxyDir in "$PWD"/*/apiproxy "$PWD"/*/*/apiproxy "$PWD"/*/*/*/apiproxy; do
  skip=false
  for excl in "${proxyExclusions[@]}"; do
    if [[ $proxyDir == *"grpc-web"* ]]; then # adding this condition to skip the "grpc" exclusion
      skip=false
    elif [[ $proxyDir == *"$excl"* ]]; then
      skip=true
    fi
  done
  if [[ $skip = false ]]; then
    echo "Running apigeelint on $proxyDir"
    apigeelint -s "$proxyDir" -f table.js -e PO013,PO025,BN003,BN005,EP002 -x tools/pipeline-linter/apigeelint --profile apigeex
  fi
done

# For Sharedflows
for sfDir in "$PWD"/*/sharedflowbundle "$PWD"/*/*/sharedflowbundle; do
  skip=false
  for excl in "${sfExclusions[@]}"; do
    if [[ $sfDir == *"$excl"* ]]; then
      skip=true
    fi
  done
  if [[ $skip = false ]]; then
    echo "Running apigeelint on $sfDir"
    apigeelint -s "$sfDir" -f table.js -e PO013,PO025,BN003,BN005 --profile apigeex
  fi
done

echo
