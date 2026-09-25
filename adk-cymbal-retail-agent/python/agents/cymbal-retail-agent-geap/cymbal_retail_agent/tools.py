# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import logging
from datetime import datetime

from google.adk.tools.mcp_tool import McpToolset, StreamableHTTPConnectionParams
from google.adk.integrations.agent_registry.agent_registry import AgentRegistry
from google.adk.auth.credential_manager import CredentialManager
from google.adk.integrations.agent_identity import GcpAuthProvider

logger = logging.getLogger("cymbal_retail_agent.tools")

# Register GCP Agent Identity Auth Provider to obtain tokens for the MCP toolset
try:
    CredentialManager.register_auth_provider(GcpAuthProvider())
except Exception:
    pass

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("PROJECT_ID")
LOCATION = os.getenv("AGENT_REGISTRY_LOCATION", os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1"))
APIGEE_HOSTNAME = os.getenv("APIGEE_HOSTNAME") or os.getenv("APIGEE_HOST") or os.getenv("APIGEE_PROD_HOSTNAME")
CONTINUE_URI = os.getenv("OAUTH_CALLBACK_URL", "http://127.0.0.1:9000/callback")

servers_list = []
if PROJECT_ID:
    try:
        registry = AgentRegistry(project_id=PROJECT_ID, location=LOCATION)
        # Search Agent Registry for the Apigee MCP Server by name
        mcp_servers_data = registry.list_mcp_servers(filter_str="displayName:cymbal-discovery-v1")
        servers_list = mcp_servers_data.get("mcpServers", [])
    except Exception as e:
        logger.warning("Failed to list MCP servers from registry: %s", e)

if servers_list:
    # Sort by updateTime descending to ensure we use the newest instance
    servers_list.sort(key=lambda x: x.get("updateTime", ""), reverse=True)
    server_name = servers_list[0]["name"]
    registry = AgentRegistry(project_id=PROJECT_ID, location=LOCATION)
    cymbal_mcp = registry.get_mcp_toolset(server_name, continue_uri=CONTINUE_URI)

    async def gcp_auth_header_provider(context):
        """Fetches the pre-seeded GcpAuthProvider token and injects it into MCP requests (including tools/list)."""
        if context and hasattr(cymbal_mcp, "get_auth_config"):
            auth_config = cymbal_mcp.get_auth_config()
            if auth_config:
                try:
                    cred = await CredentialManager(auth_config).get_auth_credential(context)
                    if cred and cred.oauth2 and cred.oauth2.access_token:
                        return {"Authorization": f"Bearer {cred.oauth2.access_token}"}
                except Exception as ex:
                    logger.warning("Pre-seeded token lookup failed: %s", ex)
        return {}

    cymbal_mcp._header_provider = gcp_auth_header_provider
else:
    # Fallback to Apigee MCP gateway directly if registry query returned no servers
    mcp_url = f"https://{APIGEE_HOSTNAME}/mcp" if APIGEE_HOSTNAME else "http://localhost:8080"
    cymbal_mcp = McpToolset(connection_params=StreamableHTTPConnectionParams(url=mcp_url))

# Configure generous connection timeout and cache TTL for robust multi-turn execution
if hasattr(cymbal_mcp, "connection_params") and cymbal_mcp.connection_params:
    cymbal_mcp.connection_params.timeout = 30.0
    cymbal_mcp.connection_params.sse_read_timeout = 60.0


def get_current_time() -> str:
    """Returns the current local time for the customer service assistant."""
    now = datetime.now()
    return now.strftime("%A, %B %d, %Y %I:%M %p")