#!/bin/sh
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

# For API Proxies
for proxyDir in "$PWD"/*/apiproxy; do
  echo "Running apigeelint on $proxyDir"
  apigeelint -s "$proxyDir" -f table.js -e PO013,PO025 -x tools/pipeline-linter/apigeelint --profile apigeex
done

# For Sharedflows
for sfDir in "$PWD"/*/sharedflowbundle; do
  echo "Running apigeelint on $sfDir"
  apigeelint -s "$sfDir" -f table.js -e PO013,PO025 --profile apigeex
done

echo
