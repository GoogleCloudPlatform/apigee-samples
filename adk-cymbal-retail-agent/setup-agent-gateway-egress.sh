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

# 1. Clean up legacy 'googleapis' service from Agent Registry if present
if gcloud agent-registry services describe "googleapis" --project="$PROJECT_ID" --location="$LOCATION" >/dev/null 2>&1; then
  echo "Cleaning up legacy 'googleapis' service from Agent Registry..."
  gcloud agent-registry services delete "googleapis" --project="$PROJECT_ID" --location="$LOCATION" --quiet || true
fi

# 2. Configure Apigee Host Endpoint in Agent Registry
echo "--- Configuring Apigee Host Endpoint (https://${APIGEE_HOST}) ---"
APIGEE_HOST_URLS=("https://${APIGEE_HOST}")
APIGEE_INTERFACES=$(build_interfaces_json "jsonrpc" "${APIGEE_HOST_URLS[@]}")
APIGEE_ENDPOINT_ID=$(register_or_update_service "apigee-host" "Apigee Host" "$APIGEE_INTERFACES")
echo "Apigee Host Endpoint ID: $APIGEE_ENDPOINT_ID"

# 3. Determine SPIFFE trust domain based on ancestry (org vs project level)
echo "Determining agent principal pool identity..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
ORG_ID=$(gcloud projects get-ancestors "$PROJECT_ID" --format="value(id,type)" 2>/dev/null | grep "organization" | awk '{print $1}')

if [ -n "$ORG_ID" ]; then
  MEMBER="principalSet://agents.global.org-${ORG_ID}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJECT_NUMBER}"
  echo "Found organization: $ORG_ID. Trust domain is organization-level."
else
  MEMBER="principalSet://agents.global.proj-${PROJECT_NUMBER}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJECT_NUMBER}"
  echo "No parent organization found. Trust domain is project-level."
fi
echo "Principal member: $MEMBER"

# 4. Look up cymbal-discovery-v1 MCP server in Agent Registry
echo "Looking up cymbal-discovery-v1 MCP server in Agent Registry..."
MCP_SERVER_NAMES=$(gcloud agent-registry mcp-servers list \
  --project="$PROJECT_ID" \
  --location="$LOCATION" \
  --filter="displayName:cymbal-discovery-v1" \
  --format="value(name)" 2>/dev/null || true)

if [ -z "$MCP_SERVER_NAMES" ]; then
  # Fallback to name search if displayName wasn't matched
  MCP_SERVER_NAMES=$(gcloud agent-registry mcp-servers list \
    --project="$PROJECT_ID" \
    --location="$LOCATION" \
    --format="value(name)" 2>/dev/null | grep -E "cymbal-discovery-v1" || true)
fi

if [ -n "$MCP_SERVER_NAMES" ]; then
  LATEST_MCP=$(echo "$MCP_SERVER_NAMES" | head -n 1)
  ACTIVE_MCP_SERVER_ID=$(basename "$LATEST_MCP")
  echo "Found active cymbal-discovery-v1 MCP Server ID: $ACTIVE_MCP_SERVER_ID"
else
  echo "Notice: cymbal-discovery-v1 not yet listed in registry; dynamic resource_type rule will govern egress."
fi

# 5. Create or Update Unified Access Policy (UAP / IAM v3)
POLICY_NAME="agent-egress-access-policy"
BINDING_NAME="agent-egress-policy-binding"

join_by() {
  local d="$1"
  shift
  local f="$1"
  shift
  printf "%s" "$f" "${@/#/$d}"
}

# IAP evaluates resource names using both project number and project ID formats.
APIGEE_ENDPOINT_CONDITIONS=(
  "destination.agent_registry.endpoint.name == 'projects/${PROJECT_ID}/locations/${LOCATION}/endpoints/${APIGEE_ENDPOINT_ID}'"
  "destination.agent_registry.endpoint.name == 'projects/${PROJECT_NUMBER}/locations/${LOCATION}/endpoints/${APIGEE_ENDPOINT_ID}'"
  "destination.unregistered.host == '${APIGEE_HOST}'"
)
APIGEE_ENDPOINT_EXPR=$(join_by " || " "${APIGEE_ENDPOINT_CONDITIONS[@]}")

# Dynamic MCP egress rule: allow any registered MCP Server in Agent Registry,
# plus the active server name if discovered.
MCP_CONDITIONS=(
  "destination.agent_registry.resource_type == 'agentregistry.googleapis.com/McpServer'"
)
if [ -n "$ACTIVE_MCP_SERVER_ID" ]; then
  MCP_CONDITIONS+=(
    "destination.agent_registry.mcp_server.name == 'projects/${PROJECT_ID}/locations/${LOCATION}/mcpServers/${ACTIVE_MCP_SERVER_ID}'"
    "destination.agent_registry.mcp_server.name == 'projects/${PROJECT_NUMBER}/locations/${LOCATION}/mcpServers/${ACTIVE_MCP_SERVER_ID}'"
  )
fi
MCP_SERVER_EXPR=$(join_by " || " "${MCP_CONDITIONS[@]}")

RULES_FILE=$(mktemp /tmp/uap-rules-XXXXXX.json)
cat <<EOF > "$RULES_FILE"
[
  {
    "description": "Allow all Google APIs",
    "effect": "ALLOW",
    "principals": [
      "$MEMBER"
    ],
    "operation": {
      "permissions": ["iap.googleapis.com/resources.egressViaIAP"]
    },
    "conditions": {
      "iap.googleapis.com": {
        "expression": "destination.unregistered.host.endsWith('googleapis.com')"
      }
    }
  },
  {
    "description": "Allow Apigee host endpoint",
    "effect": "ALLOW",
    "principals": [
      "$MEMBER"
    ],
    "operation": {
      "permissions": ["iap.googleapis.com/resources.egressViaIAP"]
    },
    "conditions": {
      "iap.googleapis.com": {
        "expression": "$APIGEE_ENDPOINT_EXPR"
      }
    }
  },
  {
    "description": "Allow registered Agent Registry MCP servers",
    "effect": "ALLOW",
    "principals": [
      "$MEMBER"
    ],
    "operation": {
      "permissions": ["iap.googleapis.com/resources.egressViaIAP"]
    },
    "conditions": {
      "iap.googleapis.com": {
        "expression": "$MCP_SERVER_EXPR"
      }
    }
  }
]
EOF

echo "--- Configuring Unified Access Policy: $POLICY_NAME ---"
if gcloud iam access-policies describe "$POLICY_NAME" --project="$PROJECT_ID" --location=global >/dev/null 2>&1; then
  echo "Access policy '$POLICY_NAME' exists. Updating rules..."
  gcloud iam access-policies update "$POLICY_NAME" \
    --details-rules="$RULES_FILE" \
    --project="$PROJECT_ID" \
    --location=global \
    --quiet
else
  echo "Creating access policy '$POLICY_NAME'..."
  gcloud iam access-policies create "$POLICY_NAME" \
    --details-rules="$RULES_FILE" \
    --project="$PROJECT_ID" \
    --location=global \
    --quiet
fi
rm -f "$RULES_FILE"

# 6. Create Policy Binding if not already created
echo "--- Configuring Policy Binding: $BINDING_NAME ---"
TARGET_RESOURCE="//cloudresourcemanager.googleapis.com/projects/${PROJECT_ID}"
POLICY_RESOURCE="projects/${PROJECT_ID}/locations/global/accessPolicies/${POLICY_NAME}"

if gcloud iam policy-bindings describe "$BINDING_NAME" --project="$PROJECT_ID" --location=global >/dev/null 2>&1; then
  echo "Policy binding '$BINDING_NAME' already exists."
else
  echo "Creating policy binding '$BINDING_NAME'..."
  gcloud iam policy-bindings create "$BINDING_NAME" \
    --policy="$POLICY_RESOURCE" \
    --target-resource="$TARGET_RESOURCE" \
    --project="$PROJECT_ID" \
    --location=global \
    --quiet
fi

# 7. Grant Agent Registry Viewer access at the project level
echo "Granting Agent Registry Viewer IAM role to agent principal pool..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="$MEMBER" \
  --role="roles/agentregistry.viewer"

# 8. Ensure Agent Gateway Service Extension uses IAP Policy Version V2 for UAP
AUTHZ_EXT="egress-gateway-iap-authzextension"
if gcloud beta service-extensions authz-extensions describe "$AUTHZ_EXT" --location="$LOCATION" >/dev/null 2>&1; then
  CURRENT_VERSION=$(gcloud beta service-extensions authz-extensions describe "$AUTHZ_EXT" --location="$LOCATION" --format="value(metadata.iapPolicyVersion)" 2>/dev/null || true)
  if [ "$CURRENT_VERSION" != "V2" ]; then
    echo "Updating $AUTHZ_EXT iapPolicyVersion to 'V2' to enable Unified Access Policy evaluation..."
    EXT_JSON=$(mktemp /tmp/authz-ext-XXXXXX.json)
    gcloud beta service-extensions authz-extensions describe "$AUTHZ_EXT" --location="$LOCATION" --format=json > "$EXT_JSON"
    python3 -c "
import json
with open('$EXT_JSON', 'r') as f:
    d = json.load(f)
d.setdefault('metadata', {})['iapPolicyVersion'] = 'V2'
d.pop('createTime', None)
d.pop('updateTime', None)
with open('$EXT_JSON', 'w') as f:
    json.dump(d, f)
"
    gcloud beta service-extensions authz-extensions import "$AUTHZ_EXT" --location="$LOCATION" --source="$EXT_JSON" --quiet
    rm -f "$EXT_JSON"
    echo "Updated $AUTHZ_EXT to iapPolicyVersion V2."
  else
    echo "Agent Gateway authz-extension ($AUTHZ_EXT) is already configured for UAP (V2)."
  fi
fi

echo "✅ Gateway egress Unified Access Policies configured successfully!"
