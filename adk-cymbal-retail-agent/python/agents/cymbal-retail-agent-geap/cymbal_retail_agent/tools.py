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
from google.adk.tools.mcp_tool import McpToolset, StreamableHTTPConnectionParams
from google.adk.integrations.agent_registry.agent_registry import AgentRegistry
from .auth_config import auth_scheme, auth_credential

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("PROJECT_ID")
LOCATION = os.getenv("AGENT_REGISTRY_LOCATION", os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1"))
APIGEE_HOSTNAME = os.getenv("APIGEE_HOSTNAME") or os.getenv("APIGEE_HOST") or os.getenv("APIGEE_PROD_HOSTNAME")

servers_list = []
if PROJECT_ID:
    try:
        registry = AgentRegistry(project_id=PROJECT_ID, location=LOCATION)
        # Search Agent Registry for the Apigee MCP Server by name
        mcp_servers_data = registry.list_mcp_servers(filter_str="displayName:cymbal-discovery-v1")
        servers_list = mcp_servers_data.get("mcpServers", [])
    except Exception as e:
        import logging
        logging.warning("Failed to list MCP servers from registry: %s", e)

if servers_list:
    # Sort by updateTime descending to ensure we use the newest instance
    servers_list.sort(key=lambda x: x.get("updateTime", ""), reverse=True)
    server_name = servers_list[0]["name"]
    registry = AgentRegistry(project_id=PROJECT_ID, location=LOCATION)
    cymbal_mcp = registry.get_mcp_toolset(
        server_name,
        auth_scheme=auth_scheme,
        auth_credential=auth_credential
    )
    # Detach internal registry closure to enable clean cloudpickle serialization for Agent Runtime
    cymbal_mcp._header_provider = None
else:
    # Fallback to Apigee MCP gateway directly if registry query returned no servers
    mcp_url = f"https://{APIGEE_HOSTNAME}/mcp" if APIGEE_HOSTNAME else "http://localhost:8080"
    cymbal_mcp = McpToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=mcp_url
        ),
        auth_scheme=auth_scheme,
        auth_credential=auth_credential
    )

# Configure generous connection timeout and cache TTL for robust multi-turn execution
if hasattr(cymbal_mcp, "connection_params") and cymbal_mcp.connection_params:
    cymbal_mcp.connection_params.timeout = 30.0
    cymbal_mcp.connection_params.sse_read_timeout = 60.0
# cymbal_mcp.tool_list_cache_ttl_seconds = 600.0

from datetime import datetime

def get_current_time() -> str:
    """Returns the current local time for the customer service assistant."""
    now = datetime.now()
    return now.strftime("%A, %B %d, %Y %I:%M %p")