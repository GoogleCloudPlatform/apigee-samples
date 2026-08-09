#!/bin/bash
set -e

if [ -z "$PROJECT_ID" ]; then
  echo "Error: PROJECT_ID is not set. Please set it in your environment."
  exit 1
fi

if [ -z "$VERTEXAI_REGION" ]; then
  echo "Error: VERTEXAI_REGION is not set. Please set it in your environment."
  exit 1
fi

echo "Cleaning up Agent Egress Policies..."
echo "Using Project ID: $PROJECT_ID"
echo "Using Location: $VERTEXAI_REGION"

# 1. Reconstruct SPIFFE pool member ID
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
ORG_ID=$(gcloud projects get-ancestors "$PROJECT_ID" --format="value(id,type)" 2>/dev/null | grep "organization" | awk '{print $1}')

if [ -n "$ORG_ID" ]; then
  MEMBER="principalSet://agents.global.org-${ORG_ID}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJECT_NUMBER}"
else
  MEMBER="principalSet://agents.global.project-${PROJECT_NUMBER}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJECT_NUMBER}"
fi
echo "Principal member: $MEMBER"

# 2. Remove Project Viewer IAM role binding
echo "Removing Agent Registry Viewer IAM role binding..."
gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
  --member="$MEMBER" \
  --role="roles/agentregistry.viewer" &>/dev/null || true

# 3. Delete registered services from Agent Registry
delete_registry_service() {
  local service_id=$1
  if gcloud agent-registry services describe "$service_id" --project="$PROJECT_ID" --location="$VERTEXAI_REGION" &>/dev/null; then
    echo "Deleting service '$service_id' from Agent Registry..."
    gcloud agent-registry services delete "$service_id" \
      --project="$PROJECT_ID" \
      --location="$VERTEXAI_REGION" \
      --quiet || true
  else
    echo "Service '$service_id' does not exist. Skipping."
  fi
}

delete_registry_service "googleapis"
delete_registry_service "apigee-host"
