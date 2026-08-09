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

PROJECT_ID=os.getenv("GOOGLE_CLOUD_PROJECT")
LOCATION=os.getenv("AGENT_REGISTRY_LOCATION", "us-central1")

registry = AgentRegistry(project_id=PROJECT_ID, location=LOCATION)

servers_list = []
try:
    # Search Agent Registry for the Apigee MCP Server by name
    mcp_servers_data = registry.list_mcp_servers(filter_str="displayName:cymbal-discovery-v1")
    servers_list = mcp_servers_data.get("mcpServers", [])
except Exception as e:
    import logging
    logging.error("Failed to list MCP servers from registry: %s", e)

if servers_list:
    # Sort by updateTime descending to ensure we use the newest instance
    servers_list.sort(key=lambda x: x.get("updateTime", ""), reverse=True)
    server_name = servers_list[0]["name"]
    cymbal_mcp = registry.get_mcp_toolset(
        server_name,
        auth_scheme=auth_scheme,
        auth_credential=auth_credential
    )
else:
    # Placeholder fallback Toolset (used during deployment import step before Agent Registry is populated)
    cymbal_mcp = McpToolset(
        connection_params=StreamableHTTPConnectionParams(
            url="http://localhost:8080"
        ),
        auth_scheme=auth_scheme,
        auth_credential=auth_credential
    )