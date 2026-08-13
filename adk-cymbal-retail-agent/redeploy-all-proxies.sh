#!/bin/bash
set -e

export PROJECT_ID="${PROJECT_ID:-apigee-ai}"
export APIGEE_ENV="${APIGEE_ENV:-qa}"
export APIGEE_HOST="${APIGEE_HOST:-34.54.87.114.nip.io}"
export SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME:-llm-cymbal-retail-agent}"
export VERTEXAI_PROJECT_ID="${VERTEXAI_PROJECT_ID:-$PROJECT_ID}"
export VERTEXAI_REGION="${VERTEXAI_REGION:-us-central1}"
export MODEL_NAME="${MODEL_NAME:-gemini-2.5-flash}"

export PATH=$PATH:$HOME/.apigeecli/bin
TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token)
export TOKEN

PRE_PROP="project_id=$VERTEXAI_PROJECT_ID
model_id=$MODEL_NAME
region=$VERTEXAI_REGION"

deploy_proxy() {
  local proxy=$1
  echo "--> Packaging & Deploying: $proxy"
  rm -rf "tmp/${proxy}"
  mkdir -p "tmp/${proxy}"
  cp -rf "proxies/${proxy}/apiproxy" "tmp/${proxy}/"
  
  if [ -d "tmp/${proxy}/apiproxy/policies" ]; then
    sed -i "" "s/APIGEE_HOST/$APIGEE_HOST/g" tmp/${proxy}/apiproxy/policies/*.xml 2>/dev/null || true
  fi
  if [ -d "tmp/${proxy}/apiproxy/resources/oas" ]; then
    sed -i "" "s/APIGEE_HOST/$APIGEE_HOST/g" tmp/${proxy}/apiproxy/resources/oas/*.yaml 2>/dev/null || true
  fi
  if [ -d "tmp/${proxy}/apiproxy/resources/properties" ]; then
    echo "$PRE_PROP" > "tmp/${proxy}/apiproxy/resources/properties/vertex_config.properties" 2>/dev/null || true
  fi
  if [ -d "tmp/${proxy}/apiproxy/targets" ]; then
    sed -i "" "s/PROJECT_ID.mcp.apigee.internal/$PROJECT_ID.mcp.apigee.internal/g" tmp/${proxy}/apiproxy/targets/*.xml 2>/dev/null || true
    sed -i "" "s/APIGEE_HOST/$APIGEE_HOST/g" tmp/${proxy}/apiproxy/targets/*.xml 2>/dev/null || true
  fi
  
  apigeecli apis create bundle -n "$proxy" \
    -f "tmp/${proxy}/apiproxy" \
    -e "$APIGEE_ENV" --token "$TOKEN" -o "$PROJECT_ID" \
    -s "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --ovr --wait
    
  rm -rf "tmp/${proxy}"
  echo "--> $proxy deployed successfully!"
}

deploy_proxy "adk-retail-agent-llm-governance-v1"
deploy_proxy "cymbal-customers-v2"
deploy_proxy "cymbal-orders-v2"
deploy_proxy "cymbal-returns-v2"
deploy_proxy "cymbal-shipping-v2"
deploy_proxy "cymbal-discovery-v1"
deploy_proxy "oauth-server"

echo "All proxies redeployed cleanly!"
