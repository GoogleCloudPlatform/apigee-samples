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

set_authz_extension_policy_version() {
  local TARGET_VERSION="$1"
  local SEEN_EXTS=""
  for AUTHZ_EXT in ${AUTHZ_EXT_NAME:-} "egress-gateway-iap-authzextension" "workshop-authz-ext"; do
    [ -z "$AUTHZ_EXT" ] && continue
    case " $SEEN_EXTS " in
      *" $AUTHZ_EXT "*) continue ;;
    esac
    SEEN_EXTS="$SEEN_EXTS $AUTHZ_EXT"

    if gcloud beta service-extensions authz-extensions describe "$AUTHZ_EXT" --location="$LOCATION" --project="$PROJECT_ID" >/dev/null 2>&1; then
      local CURRENT_VERSION
      CURRENT_VERSION=$(gcloud beta service-extensions authz-extensions describe "$AUTHZ_EXT" --location="$LOCATION" --project="$PROJECT_ID" --format="value(metadata.iapPolicyVersion)" 2>/dev/null || true)
      if [ "$CURRENT_VERSION" != "$TARGET_VERSION" ]; then
        echo "Updating $AUTHZ_EXT iapPolicyVersion to '$TARGET_VERSION'..."
        local EXT_JSON
        EXT_JSON=$(mktemp /tmp/authz-ext-XXXXXX.json)
        gcloud beta service-extensions authz-extensions describe "$AUTHZ_EXT" --location="$LOCATION" --project="$PROJECT_ID" --format=json > "$EXT_JSON"
        python3 -c "
import json
with open('$EXT_JSON', 'r') as f:
    d = json.load(f)
d.setdefault('metadata', {})['iapPolicyVersion'] = '$TARGET_VERSION'
d.pop('createTime', None)
d.pop('updateTime', None)
with open('$EXT_JSON', 'w') as f:
    json.dump(d, f)
"
        gcloud beta service-extensions authz-extensions import "$AUTHZ_EXT" --location="$LOCATION" --project="$PROJECT_ID" --source="$EXT_JSON" --quiet
        rm -f "$EXT_JSON"
        echo "Updated $AUTHZ_EXT to iapPolicyVersion $TARGET_VERSION."
      else
        echo "Agent Gateway authz-extension ($AUTHZ_EXT) is already configured for iapPolicyVersion $TARGET_VERSION."
      fi
    fi
  done
}

# 1. Configure Apigee Host Endpoint in Agent Registry
echo "--- Configuring Apigee Host Endpoint (https://${APIGEE_HOST}) ---"
APIGEE_HOST_URLS=("https://${APIGEE_HOST}")
APIGEE_INTERFACES=$(build_interfaces_json "jsonrpc" "${APIGEE_HOST_URLS[@]}")
APIGEE_ENDPOINT_ID=$(register_or_update_service "apigee-host" "Apigee Host" "$APIGEE_INTERFACES")
echo "Apigee Host Endpoint ID: $APIGEE_ENDPOINT_ID"

# 2. Determine SPIFFE trust domain based on ancestry (org vs project level)
echo "Determining agent principal pool identity..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
ORG_ID=$(gcloud projects get-ancestors "$PROJECT_ID" --format="value(id,type)" 2>/dev/null | grep "organization" | awk '{print $1}' || true)

if [ -n "$ORG_ID" ]; then
  MEMBER="principalSet://agents.global.org-${ORG_ID}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJECT_NUMBER}"
  echo "Found organization: $ORG_ID. Trust domain is organization-level."
else
  MEMBER="principalSet://agents.global.project-${PROJECT_NUMBER}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJECT_NUMBER}"
  echo "No parent organization found. Trust domain is project-level."
fi
echo "Principal member: $MEMBER"

# 3. Grant Agent Registry Viewer access at the project level
echo "Granting Agent Registry Viewer IAM role to agent principal pool..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="$MEMBER" \
  --role="roles/agentregistry.viewer" >/dev/null

# 4. Look up cymbal-discovery-v1 MCP server in Agent Registry (optional at bootstrap)
echo "Looking up cymbal-discovery-v1 MCP server in Agent Registry..."
ACTIVE_MCP_SERVER_ID=""
MCP_SERVER_NAMES=$(gcloud agent-registry mcp-servers list \
  --project="$PROJECT_ID" \
  --location="$LOCATION" \
  --filter="displayName:cymbal-discovery-v1" \
  --format="value(name)" 2>/dev/null || true)

if [ -z "$MCP_SERVER_NAMES" ]; then
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
  echo "Notice: cymbal-discovery-v1 not yet listed in registry; dynamic registry rule will govern egress."
fi

# 5. Attempt Unified Access Policy (UAP / IAM v3) first; fall back to IAP v1 Registry-Wide Allow Policy if blocked by Org Policy
POLICY_NAME="agent-egress-access-policy"
BINDING_NAME="agent-egress-policy-binding"

join_by() {
  local d="$1"
  shift
  local f="$1"
  shift
  printf "%s" "$f" "${@/#/$d}"
}

APIGEE_ENDPOINT_CONDITIONS=(
  "destination.agent_registry.endpoint.name == 'projects/${PROJECT_ID}/locations/${LOCATION}/endpoints/${APIGEE_ENDPOINT_ID}'"
  "destination.agent_registry.endpoint.name == 'projects/${PROJECT_NUMBER}/locations/${LOCATION}/endpoints/${APIGEE_ENDPOINT_ID}'"
  "destination.unregistered.host == '${APIGEE_HOST}'"
)
APIGEE_ENDPOINT_EXPR=$(join_by " || " "${APIGEE_ENDPOINT_CONDITIONS[@]}")

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

UAP_POLICY_READY="false"
UAP_BOUND="false"

echo "--- Attempting Unified Access Policy (V2): $POLICY_NAME ---"
if gcloud iam access-policies describe "$POLICY_NAME" --project="$PROJECT_ID" --location=global >/dev/null 2>&1; then
  echo "Access policy '$POLICY_NAME' exists. Updating rules..."
  if gcloud iam access-policies update "$POLICY_NAME" \
    --details-rules="$RULES_FILE" \
    --project="$PROJECT_ID" \
    --location=global \
    --quiet; then
    UAP_POLICY_READY="true"
  fi
else
  echo "Creating access policy '$POLICY_NAME'..."
  if gcloud iam access-policies create "$POLICY_NAME" \
    --details-rules="$RULES_FILE" \
    --project="$PROJECT_ID" \
    --location=global \
    --quiet; then
    UAP_POLICY_READY="true"
  fi
fi
rm -f "$RULES_FILE"

if [ "$UAP_POLICY_READY" = "true" ]; then
  echo "--- Configuring Policy Binding: $BINDING_NAME ---"
  TARGET_RESOURCE="//cloudresourcemanager.googleapis.com/projects/${PROJECT_ID}"
  POLICY_RESOURCE="projects/${PROJECT_ID}/locations/global/accessPolicies/${POLICY_NAME}"

  if gcloud iam policy-bindings describe "$BINDING_NAME" --project="$PROJECT_ID" --location=global >/dev/null 2>&1; then
    echo "Policy binding '$BINDING_NAME' already exists."
    UAP_BOUND="true"
  else
    echo "Creating policy binding '$BINDING_NAME'..."
    if gcloud iam policy-bindings create "$BINDING_NAME" \
      --policy="$POLICY_RESOURCE" \
      --target-resource="$TARGET_RESOURCE" \
      --project="$PROJECT_ID" \
      --location=global \
      --quiet; then
      UAP_BOUND="true"
    fi
  fi
fi

if [ "$UAP_BOUND" = "true" ]; then
  # Clean up legacy 'googleapis' service from Agent Registry if present (handled via UAP wildcard rule)
  if gcloud agent-registry services describe "googleapis" --project="$PROJECT_ID" --location="$LOCATION" >/dev/null 2>&1; then
    echo "Cleaning up legacy 'googleapis' service from Agent Registry..."
    gcloud agent-registry services delete "googleapis" --project="$PROJECT_ID" --location="$LOCATION" --quiet || true
  fi

  set_authz_extension_policy_version "V2"
  echo "✅ Gateway egress Unified Access Policies (V2) configured successfully!"
else
  echo "⚠️ Notice: Unable to bind IAM v3 Unified Access Policy (e.g., 'constraints/iam.managed.disableAccessPolicyBindings' enforced at parent org/folder)."
  echo "--- Falling back to IAP v1 Registry-Wide Allow Policy ---"

  # Remove orphaned unattached access policy if created above
  if gcloud iam access-policies describe "$POLICY_NAME" --project="$PROJECT_ID" --location=global >/dev/null 2>&1; then
    gcloud iam access-policies delete "$POLICY_NAME" --project="$PROJECT_ID" --location=global --quiet >/dev/null 2>&1 || true
  fi

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
    "https://apihub.googleapis.com"
    "https://${LOCATION}-apihub.googleapis.com"
    "https://discoveryengine.googleapis.com"
    "https://${LOCATION}-discoveryengine.googleapis.com"
    "https://modelarmor.googleapis.com"
    "https://modelarmor.${LOCATION}.rep.googleapis.com"
    "https://modelarmor.${LOCATION}.rep.mtls.googleapis.com"
    "https://dlp.googleapis.com"
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
  if [ "$LOCATION" != "us-central1" ]; then
    GOOGLE_API_URLS+=(
      "https://us-central1-agentregistry.googleapis.com"
      "https://us-central1-agentregistry.mtls.googleapis.com"
      "https://agentregistry.us-central1.rep.googleapis.com"
      "https://us-central1-aiplatform.googleapis.com"
      "https://us-central1-aiplatform.mtls.googleapis.com"
      "https://aiplatform.us-central1.rep.googleapis.com"
      "https://us-central1-apihub.googleapis.com"
      "https://us-central1-discoveryengine.googleapis.com"
      "https://modelarmor.us-central1.rep.googleapis.com"
      "https://modelarmor.us-central1.rep.mtls.googleapis.com"
    )
  fi

  echo "--- Configuring Google APIs Endpoint in Agent Registry ---"
  GOOGLE_INTERFACES=$(build_interfaces_json "jsonrpc" "${GOOGLE_API_URLS[@]}")
  GOOGLE_ENDPOINT_ID=$(register_or_update_service "googleapis" "Google APIs" "$GOOGLE_INTERFACES")
  echo "Google APIs Endpoint ID: $GOOGLE_ENDPOINT_ID"

  echo "Applying registry-wide IAP egress IAM binding across Agent Registry ($LOCATION)..."
  gcloud beta iap web add-iam-policy-binding \
    --resource-type=agent-registry \
    --region="$LOCATION" \
    --project="$PROJECT_ID" \
    --member="$MEMBER" \
    --role=roles/iap.egressor

  gcloud beta iap web add-iam-policy-binding \
    --resource-type=agent-registry \
    --region=global \
    --project="$PROJECT_ID" \
    --member="$MEMBER" \
    --role=roles/iap.egressor >/dev/null 2>&1 || true

  set_authz_extension_policy_version "V1"
  echo "✅ Gateway egress IAP Registry-Wide Allow Policy (V1) configured successfully!"
fi
