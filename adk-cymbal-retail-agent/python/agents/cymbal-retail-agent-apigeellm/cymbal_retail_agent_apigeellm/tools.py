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
from google.adk.tools.apihub_tool.apihub_toolset import APIHubToolset
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
from google.adk.tools.mcp_tool.mcp_toolset import StreamableHTTPConnectionParams
from .auth_config import auth_scheme, auth_credential

APIGEE_HOSTNAME=os.getenv("APIGEE_HOSTNAME")

# Cymbal MCP
cymbal_mcp = MCPToolset(
    connection_params=StreamableHTTPConnectionParams(
        url=f"https://{APIGEE_HOSTNAME}/mcp"
    ),
    errlog=None,
    auth_scheme=auth_scheme,
    auth_credential=auth_credential,
)