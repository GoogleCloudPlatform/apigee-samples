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

from google.adk.tools.apihub_tool.apihub_toolset import APIHubToolset
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
from google.adk.tools.mcp_tool.mcp_toolset import StreamableHTTPConnectionParams
from google.adk.tools.apihub_tool.clients.secret_client import SecretManagerClient
from google.adk.tools.openapi_tool.auth.auth_helpers import token_to_scheme_credential

load_dotenv()

PROJECT_ID=os.getenv("GOOGLE_CLOUD_PROJECT")
LOCATION=os.getenv("GOOGLE_CLOUD_LOCATION")
API_HUB_LOCATION=f"projects/{PROJECT_ID}/locations/{LOCATION}/apis"
SECRET=f"projects/{PROJECT_ID}/secrets/cymbal-retail-apikey/versions/latest"

# # Get the credentials for the Cymbal Auto APIs
secret_manager_client = SecretManagerClient()
apikey_credential_str = secret_manager_client.get_secret(SECRET)    
auth_scheme, auth_credential = token_to_scheme_credential("apikey", "header", "x-apikey", apikey_credential_str)


# Customer Profile API
customer_profile = APIHubToolset(
    name="cymbal-customer-profile-api",
    description="Retrieve comprehensive profile for customer API",
    apihub_resource_name=f"{API_HUB_LOCATION}/customers_api",
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)
# Orders API
orders = APIHubToolset(
    name="cymbal-orders-status-api",
    description="Retrieve customer orders API",
    apihub_resource_name=f"{API_HUB_LOCATION}/orders_api",
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)

# Return and Refund API
returns = APIHubToolset(
    name="cymbal-returns-api",
    description="Handle customer returns API",
    apihub_resource_name=f"{API_HUB_LOCATION}/returns_api",
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)

membership = MCPToolset(
    connection_params=StreamableHTTPConnectionParams(
        url="https://34.54.87.114.nip.io/mcp/v1/samples/adk-cymbal-retail"
    ),
    errlog=None,
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)
# Inventory  ( Integration Connector ToolSet)
# inventory = APIHubToolset(
#     name="cymbal-inventory-api",
#     description="Check stock for a specific product API",
#     apihub_resource_name=f"{API_HUB_LOCATION}/inventory_api",
#     auth_scheme=auth_scheme,
#     auth_credential=auth_credential
# )



