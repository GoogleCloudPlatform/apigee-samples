#!/bin/bash

# Copyright 2026 Google LLC
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

echo "=================================================================="
echo "    CYMBAL RETAIL: QWIKLABS GEMMA 3 (4B) WORKSHOP SETUP           "
echo "=================================================================="

# 1. Source environment variables
if [ -f "env.sh" ]; then
  echo "--> Sourcing environment variables from env.sh..."
  source env.sh
fi

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" == "(unset)" ]; then
  echo "Error: PROJECT_ID is not set. Please run 'gcloud config set project <PROJECT_ID>' or edit env.sh"
  exit 1
fi

echo "--> Target Project: $PROJECT_ID"

# 2. Deploy CPU-optimized Gemma 3 (4B) on Cloud Run
echo ""
echo "--> Step 1/2: Deploying Gemma 3 (4B) on Cloud Run (CPU / Scale-to-Zero)..."
./deploy-gemma-cpu-cloudrun.sh

# 3. Test and Validate Hybrid Routing & AI Governance
echo ""
echo "--> Step 2/2: Validating Apigee Hybrid Model Routing & AI Safety..."
python3 test-hybrid-routing.py

echo ""
echo "=================================================================="
echo "  QWIKLABS GEMMA WORKSHOP ENVIRONMENT READY!                     "
echo "=================================================================="
echo "  1. Simple prompts & mock calls route to private Gemma 3 (4B)."
echo "  2. Complex multi-agent reasoning routes to Gemini 2.5 Flash."
echo "  3. Google Cloud Model Armor and Cloud DLP protect both paths."
echo "=================================================================="
