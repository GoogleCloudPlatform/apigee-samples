#!/bin/bash
set -e

echo "================================================================="
echo "   CYMBAL RETAIL: AUTOMATED GATEWAY & GOVERNANCE TEST SUITE      "
echo "================================================================="

export APIGEE_HOST="${APIGEE_HOST:-34.54.87.114.nip.io}"
export APIKEY="${APIKEY:-PXifa5UsWH2WhPSJfZGabR7mVndqlWMtANUYjtAWYALC7Tbb}"
export APISECRET="${APISECRET:-d01QHF9Ot8JPDBdm1nRdQQWtDV0AkyBCZCWAuz4MAx0Dj8Mmt3mpjAgdDGpvWGGK}"
export PROJECT_ID="${PROJECT_ID:-apigee-ai}"

echo "🔒 Testing against Apigee Gateway Host: https://${APIGEE_HOST}"
echo "🔑 Using Enterprise Consumer API Key: ${APIKEY:0:5}....${APIKEY: -5}"

if [ -z "$APP_DEFAULT_TOKEN" ]; then
    echo "🔄 Fetching fresh Google Cloud Application Default Access Token..."
    export APP_DEFAULT_TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || echo 'mock-token')"
fi

echo "🚀 Executing automated BDD Apickli Cucumber suites..."
npm test
