#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "$PROJECT_ID" ] && [ -f "$SCRIPT_DIR/env.sh" ] && ! grep -q "PROJECT_ID_TO_SET" "$SCRIPT_DIR/env.sh"; then
  source "$SCRIPT_DIR/env.sh"
fi

PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-$PROJECT_ID}
LOCATION=${VERTEXAI_REGION:-${AGENT_REGISTRY_LOCATION:-us-central1}}

if [ -z "$PROJECT_ID" ]; then
  echo "Error: PROJECT_ID is not set. Please set it in your environment or env.sh."
  exit 1
fi

if [ -z "$APIGEE_HOST" ]; then
  echo "Error: APIGEE_HOST is not set. Please set it in your environment or env.sh."
  exit 1
fi

register_or_update_service() {
  local SERVICE_NAME="$1"
  local DISPLAY_NAME="$2"
  local INTERFACES_JSON="$3"

  echo "Checking if '$SERVICE_NAME' service exists in Agent Registry..." >&2
  local REGISTRY_RESOURCE=""
  if gcloud agent-registry services describe "$SERVICE_NAME" --project="$PROJECT_ID" --location="$LOCATION" >/dev/null 2>&1; then
    echo "Service '$SERVICE_NAME' already exists. Updating configuration..." >&2
    REGISTRY_RESOURCE=$(gcloud agent-registry services update "$SERVICE_NAME" \
      --project="$PROJECT_ID" \
      --location="$LOCATION" \
      --display-name="$DISPLAY_NAME" \
      --endpoint-spec-type=no-spec \
      --interfaces="$INTERFACES_JSON" \
      --format="value(registryResource)")
  else
    echo "Registering '$SERVICE_NAME' in Agent Registry..." >&2
    REGISTRY_RESOURCE=$(gcloud agent-registry services create "$SERVICE_NAME" \
      --project="$PROJECT_ID" \
      --location="$LOCATION" \
      --display-name="$DISPLAY_NAME" \
      --endpoint-spec-type=no-spec \
      --interfaces="$INTERFACES_JSON" \
      --format="value(registryResource)")
  fi

  if [ -z "$REGISTRY_RESOURCE" ]; then
    REGISTRY_RESOURCE=$(gcloud agent-registry services describe "$SERVICE_NAME" \
      --project="$PROJECT_ID" \
      --location="$LOCATION" \
      --format="value(registryResource)")
  fi

  basename "$REGISTRY_RESOURCE"
}

build_interfaces_json() {
  local PROTOCOL="$1"
  shift
  local URLS=("$@")
  local JSON="["
  local FIRST=1
  for URL in "${URLS[@]}"; do
    if [ $FIRST -eq 1 ]; then
      FIRST=0
    else
      JSON+=", "
    fi
    JSON+="{\"url\": \"$URL\", \"protocolBinding\": \"$PROTOCOL\"}"
  done
  JSON+="]"
  echo "$JSON"
}

# 1a. Base URLs for Google APIs
GOOGLE_API_URLS=(
  "https://agentregistry.googleapis.com"
  "https://agentregistry.mtls.googleapis.com"
  "https://${LOCATION}-agentregistry.googleapis.com"
  "https://${LOCATION}-agentregistry.mtls.googleapis.com"
  "https://agentregistry.${LOCATION}.rep.googleapis.com"

  "https://aiplatform.googleapis.com"
  "https://aiplatform.mtls.googleapis.com"
  "https://${LOCATION}-aiplatform.googleapis.com"
  "https://${LOCATION}-aiplatform.mtls.googleapis.com"
  "https://aiplatform.${LOCATION}.rep.googleapis.com"

  "https://generativelanguage.googleapis.com"
  "https://generativelanguage.mtls.googleapis.com"

  "https://agentidentity.googleapis.com"
  "https://agentidentity.mtls.googleapis.com"
  "https://agentidentitycredentials.googleapis.com"
  "https://agentidentitycredentials.mtls.googleapis.com"
  "https://iamcredentials.googleapis.com"
  "https://iamcredentials.mtls.googleapis.com"
  "https://oauth2.googleapis.com"
  "https://accounts.google.com"

  "https://telemetry.googleapis.com"
  "https://telemetry.mtls.googleapis.com"
  "https://logging.googleapis.com"
  "https://logging.mtls.googleapis.com"
  "https://monitoring.googleapis.com"
  "https://monitoring.mtls.googleapis.com"
  "https://cloudtrace.googleapis.com"
  "https://cloudtrace.mtls.googleapis.com"

  "https://cloudresourcemanager.googleapis.com"
  "https://cloudresourcemanager.mtls.googleapis.com"
  "https://storage.googleapis.com"
  "https://storage.mtls.googleapis.com"
  "https://secretmanager.googleapis.com"
  "https://secretmanager.mtls.googleapis.com"
)

GOOGLE_INTERFACES=$(build_interfaces_json "jsonrpc" "${GOOGLE_API_URLS[@]}")

APIGEE_HOST_URLS=("https://${APIGEE_HOST}")
APIGEE_INTERFACES=$(build_interfaces_json "jsonrpc" "${APIGEE_HOST_URLS[@]}")

ENDPOINTS=()

# 1a. Configure Google APIs Endpoint
echo "--- Configuring Google APIs Endpoint ---"
GOOGLE_ENDPOINT_ID=$(register_or_update_service "googleapis" "Google APIs" "$GOOGLE_INTERFACES")
echo "Google APIs Endpoint ID: $GOOGLE_ENDPOINT_ID"
ENDPOINTS+=("$GOOGLE_ENDPOINT_ID")

# 1b. Configure Apigee Host Endpoint
echo "--- Configuring Apigee Host Endpoint (https://${APIGEE_HOST}) ---"
APIGEE_ENDPOINT_ID=$(register_or_update_service "apigee-host" "Apigee Host" "$APIGEE_INTERFACES")
echo "Apigee Host Endpoint ID: $APIGEE_ENDPOINT_ID"
ENDPOINTS+=("$APIGEE_ENDPOINT_ID")

# 2. Determine SPIFFE trust domain based on ancestry (org vs project level)
echo "Determining agent principal pool identity..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
ORG_ID=$(gcloud projects get-ancestors "$PROJECT_ID" --format="value(id,type)" 2>/dev/null | grep "organization" | awk '{print $1}')

if [ -n "$ORG_ID" ]; then
  MEMBER="principalSet://agents.global.org-${ORG_ID}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJECT_NUMBER}"
  echo "Found organization: $ORG_ID. Trust domain is organization-level."
else
  MEMBER="principalSet://agents.global.project-${PROJECT_NUMBER}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJECT_NUMBER}"
  echo "No parent organization found. Trust domain is project-level."
fi
echo "Principal member: $MEMBER"

# 3. Add the IAM policy binding for IAP on all registered service endpoints
echo "Applying IAP egress IAM bindings for service endpoints..."
for ENDPOINT_ID in "${ENDPOINTS[@]}"; do
  echo "Applying IAP egress IAM binding for endpoint: $ENDPOINT_ID"
  gcloud beta iap web add-iam-policy-binding \
    --resource-type=agent-registry \
    --endpoint="$ENDPOINT_ID" \
    --region="$LOCATION" \
    --project="$PROJECT_ID" \
    --member="$MEMBER" \
    --role=roles/iap.egressor
done

# 3b. Add the IAM policy binding for all MCP servers in the Agent Registry
echo "Retrieving registered MCP servers..."
MCP_SERVERS=$(gcloud agent-registry mcp-servers list \
  --project="$PROJECT_ID" \
  --location="$LOCATION" \
  --format="value(name)" 2>/dev/null || true)

for SERVER in $MCP_SERVERS; do
  SERVER_ID=$(basename "$SERVER")
  echo "Applying IAP egress IAM binding for MCP server: $SERVER_ID"
  gcloud beta iap web add-iam-policy-binding \
    --resource-type=agent-registry \
    --mcp-server="$SERVER_ID" \
    --region="$LOCATION" \
    --project="$PROJECT_ID" \
    --member="$MEMBER" \
    --role=roles/iap.egressor
done

# 4. Grant Agent Registry Viewer access at the project level
echo "Granting Agent Registry Viewer IAM role to agent principal pool..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="$MEMBER" \
  --role="roles/agentregistry.viewer"

echo "✅ Gateway egress policies configured successfully!"
