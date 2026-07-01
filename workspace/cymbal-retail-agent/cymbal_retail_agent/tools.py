# Copyright 2025 Google LLC
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
from dotenv import load_dotenv

from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
from google.adk.tools.mcp_tool.mcp_toolset import StreamableHTTPConnectionParams
from google.adk.tools.apihub_tool.clients.secret_client import SecretManagerClient
from google.adk.tools.openapi_tool.auth.auth_helpers import token_to_scheme_credential

load_dotenv()

PROJECT_ID=os.getenv("GOOGLE_CLOUD_PROJECT")
APIGEE_HOSTNAME=os.getenv("APIGEE_HOSTNAME")
SECRET=f"projects/{PROJECT_ID}/secrets/cymbal-retail-apikey/versions/latest"

# # Get the credentials for the Cymbal Retail APIs
secret_manager_client = SecretManagerClient()
apikey_credential_str = secret_manager_client.get_secret(SECRET)
auth_scheme, auth_credential = token_to_scheme_credential("apikey", "header", "x-apikey", apikey_credential_str)

mcp_protocol = "http" if "localhost" in APIGEE_HOSTNAME or "127.0.0.1" in APIGEE_HOSTNAME else "https"

# Orders API
orders = MCPToolset(
    connection_params=StreamableHTTPConnectionParams(
        url=f"{mcp_protocol}://{APIGEE_HOSTNAME}/mcp/v1/samples/adk-cymbal-retail/orders",
        headers={"x-apikey": apikey_credential_str}
    ),
    errlog=None,
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)

# Return and Refund API
returns = MCPToolset(
    connection_params=StreamableHTTPConnectionParams(
        url=f"{mcp_protocol}://{APIGEE_HOSTNAME}/mcp/v1/samples/adk-cymbal-retail/returns",
        headers={"x-apikey": apikey_credential_str}
    ),
    errlog=None,
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)

# Customers API
customers = MCPToolset(
    connection_params=StreamableHTTPConnectionParams(
        url=f"{mcp_protocol}://{APIGEE_HOSTNAME}/mcp/v1/samples/adk-cymbal-retail/customers",
        headers={"x-apikey": apikey_credential_str}
    ),
    errlog=None,
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)

# Shipping API
shipping = MCPToolset(
    connection_params=StreamableHTTPConnectionParams(
        url=f"{mcp_protocol}://{APIGEE_HOSTNAME}/mcp/v1/samples/adk-cymbal-retail/shipping",
        headers={"x-apikey": apikey_credential_str}
    ),
    errlog=None,
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)
