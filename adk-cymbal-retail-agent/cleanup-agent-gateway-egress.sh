#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/env.sh" ]; then
  source "$SCRIPT_DIR/env.sh"
fi

PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-$PROJECT_ID}
LOCATION=${VERTEXAI_REGION:-${AGENT_REGISTRY_LOCATION:-us-central1}}

if [ -z "$PROJECT_ID" ]; then
  echo "Error: PROJECT_ID is not set. Please set it in your environment or env.sh."
  exit 1
fi

echo "Cleaning up Agent Egress Policies..."
echo "Using Project ID: $PROJECT_ID"
echo "Using Location: $LOCATION"

# 1. Reconstruct SPIFFE pool member ID
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
ORG_ID=$(gcloud projects get-ancestors "$PROJECT_ID" --format="value(id,type)" 2>/dev/null | grep "organization" | awk '{print $1}')

if [ -n "$ORG_ID" ]; then
  MEMBER="principalSet://agents.global.org-${ORG_ID}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJECT_NUMBER}"
else
  MEMBER="principalSet://agents.global.proj-${PROJECT_NUMBER}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJECT_NUMBER}"
fi
echo "Principal member: $MEMBER"

# 2. Remove Project Viewer IAM role binding
echo "Removing Agent Registry Viewer IAM role binding..."
gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
  --member="$MEMBER" \
  --role="roles/agentregistry.viewer" &>/dev/null || true

# 3. Delete Unified Access Policy Binding and Policy
BINDING_NAME="agent-egress-policy-binding"
POLICY_NAME="agent-egress-access-policy"

if gcloud iam policy-bindings describe "$BINDING_NAME" --project="$PROJECT_ID" --location=global &>/dev/null; then
  echo "Deleting policy binding '$BINDING_NAME'..."
  gcloud iam policy-bindings delete "$BINDING_NAME" --project="$PROJECT_ID" --location=global --quiet || true
fi

if gcloud iam access-policies describe "$POLICY_NAME" --project="$PROJECT_ID" --location=global &>/dev/null; then
  echo "Deleting access policy '$POLICY_NAME'..."
  gcloud iam access-policies delete "$POLICY_NAME" --project="$PROJECT_ID" --location=global --quiet || true
fi

# 4. Remove any legacy IAP egress bindings if present
echo "Removing any legacy IAP egress IAM bindings..."
EMPTY_IAP_POLICY=$(mktemp /tmp/empty-iap-XXXXXX.json)
echo '{"bindings":[]}' > "$EMPTY_IAP_POLICY"

# Reset registry-level legacy IAP policies (global and regional)
gcloud beta iap web set-iam-policy "$EMPTY_IAP_POLICY" --resource-type=agent-registry --project="$PROJECT_ID" --quiet &>/dev/null || true
gcloud beta iap web set-iam-policy "$EMPTY_IAP_POLICY" --resource-type=agent-registry --region="$LOCATION" --project="$PROJECT_ID" --quiet &>/dev/null || true

for ENDPOINT in $(gcloud agent-registry endpoints list --project="$PROJECT_ID" --location="$LOCATION" --format="value(name)" 2>/dev/null || true); do
  ENDPOINT_ID=$(basename "$ENDPOINT")
  gcloud beta iap web remove-iam-policy-binding \
    --resource-type=agent-registry \
    --endpoint="$ENDPOINT_ID" \
    --region="$LOCATION" \
    --project="$PROJECT_ID" \
    --member="$MEMBER" \
    --role=roles/iap.egressor &>/dev/null || true
done

for SERVER in $(gcloud agent-registry mcp-servers list --project="$PROJECT_ID" --location="$LOCATION" --format="value(name)" 2>/dev/null || true); do
  SERVER_ID=$(basename "$SERVER")
  gcloud beta iap web remove-iam-policy-binding \
    --resource-type=agent-registry \
    --mcp-server="$SERVER_ID" \
    --region="$LOCATION" \
    --project="$PROJECT_ID" \
    --member="$MEMBER" \
    --role=roles/iap.egressor &>/dev/null || true
done
rm -f "$EMPTY_IAP_POLICY"

# 5. Delete registered services from Agent Registry
delete_registry_service() {
  local service_id=$1
  if gcloud agent-registry services describe "$service_id" --project="$PROJECT_ID" --location="$LOCATION" &>/dev/null; then
    echo "Deleting service '$service_id' from Agent Registry..."
    gcloud agent-registry services delete "$service_id" \
      --project="$PROJECT_ID" \
      --location="$LOCATION" \
      --quiet || true
  else
    echo "Service '$service_id' does not exist. Skipping."
  fi
}

delete_registry_service "googleapis"
delete_registry_service "apigee-host"

echo "✅ Gateway egress cleanup completed successfully!"
