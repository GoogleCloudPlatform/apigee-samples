#!/bin/bash
set -e

if [ -z "$PROJECT_ID" ]; then
  echo "Error: PROJECT_ID is not set. Please set it in your environment."
  exit 1
fi

if [ -z "$APIGEE_HOST" ]; then
  echo "Error: APIGEE_HOST is not set. Please set it in your environment."
  exit 1
fi

if [ -z "$VERTEXAI_REGION" ]; then
  echo "Error: VERTEXAI_REGION is not set. Please set it in your environment."
  exit 1
fi

ensure_service() {
  local service_id=$1
  local display_name=$2
  local interfaces=$3
  local resource
  
  echo "Ensuring service '$service_id' in Agent Registry..." >&2
  if resource=$(gcloud agent-registry services describe "$service_id" --project="$PROJECT_ID" --location="$VERTEXAI_REGION" --format="value(registryResource)" 2>/dev/null); then
    echo "Service '$service_id' already exists." >&2
  else
    echo "Creating service '$service_id'..." >&2
    resource=$(gcloud agent-registry services create "$service_id" \
      --project="$PROJECT_ID" \
      --location="$VERTEXAI_REGION" \
      --display-name="$display_name" \
      --endpoint-spec-type=no-spec \
      --interfaces="$interfaces" \
      --format="value(registryResource)")
  fi
  basename "$resource"
}

# 1. Register the service endpoints in Agent Registry
ENDPOINT_ID=$(ensure_service "googleapis" "Google APIs" "[
  {\"url\": \"https://agentregistry.googleapis.com\", \"protocolBinding\": \"jsonrpc\"},
  {\"url\": \"https://aiplatform.mtls.googleapis.com\", \"protocolBinding\": \"grpc\"},
  {\"url\": \"https://cloudresourcemanager.mtls.googleapis.com\", \"protocolBinding\": \"jsonrpc\"},
  {\"url\": \"https://iamcredentials.mtls.googleapis.com\", \"protocolBinding\": \"jsonrpc\"},
  {\"url\": \"https://iamconnectorcredentials.googleapis.com\", \"protocolBinding\": \"jsonrpc\"},
  {\"url\": \"https://iamconnectorcredentials.mtls.googleapis.com\", \"protocolBinding\": \"jsonrpc\"},
  {\"url\": \"https://telemetry.mtls.googleapis.com\", \"protocolBinding\": \"jsonrpc\"},
  {\"url\": \"https://${VERTEXAI_REGION}-aiplatform.mtls.googleapis.com\", \"protocolBinding\": \"grpc\"},
  {\"url\": \"https://${VERTEXAI_REGION}-aiplatform.googleapis.com\", \"protocolBinding\": \"grpc\"},
  {\"url\": \"https://aiplatform.${VERTEXAI_REGION}.rep.googleapis.com\", \"protocolBinding\": \"grpc\"},
  {\"url\": \"https://logging.googleapis.com\", \"protocolBinding\": \"grpc\"},
  {\"url\": \"https://logging.mtls.googleapis.com\", \"protocolBinding\": \"grpc\"}
]")
echo "Google APIs Endpoint ID: $ENDPOINT_ID"

APIGEE_ENDPOINT_ID=$(ensure_service "apigee-host" "Apigee Host" "[
  {\"url\": \"https://${APIGEE_HOST}\", \"protocolBinding\": \"jsonrpc\"}
]")
echo "Apigee Host Endpoint ID: $APIGEE_ENDPOINT_ID"

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

# 3. Add the IAM policy binding for IAP
echo "Applying IAP egress IAM binding for Google APIs..."
gcloud beta iap web add-iam-policy-binding \
  --resource-type=agent-registry \
  --endpoint="$ENDPOINT_ID" \
  --region="$VERTEXAI_REGION" \
  --project="$PROJECT_ID" \
  --member="$MEMBER" \
  --role=roles/iap.egressor

echo "Applying IAP egress IAM binding for Apigee Host..."
gcloud beta iap web add-iam-policy-binding \
  --resource-type=agent-registry \
  --endpoint="$APIGEE_ENDPOINT_ID" \
  --region="$VERTEXAI_REGION" \
  --project="$PROJECT_ID" \
  --member="$MEMBER" \
  --role=roles/iap.egressor

# # 3b. Add the IAM policy binding for all MCP servers in the Agent Registry
# echo "Retrieving registered MCP servers..."
# MCP_SERVERS=$(gcloud agent-registry mcp-servers list \
#   --project="$PROJECT_ID" \
#   --location="$VERTEXAI_REGION" \
#   --format="value(name)" 2>/dev/null || true)

# for SERVER in $MCP_SERVERS; do
#   SERVER_ID=$(basename "$SERVER")
#   echo "Applying IAP egress IAM binding for MCP server: $SERVER_ID"
#   gcloud beta iap web add-iam-policy-binding \
#     --resource-type=agent-registry \
#     --mcp-server="$SERVER_ID" \
#     --region="$VERTEXAI_REGION" \
#     --project="$PROJECT_ID" \
#     --member="$MEMBER" \
#     --role=roles/iap.egressor
# done

# 4. Grant Agent Registry Viewer access at the project level
echo "Granting Agent Registry Viewer IAM role to agent principal pool..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="$MEMBER" \
  --role="roles/agentregistry.viewer"

echo "✅ Gateway egress policies configured successfully!"
