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
from google.adk.tools.application_integration_tool.application_integration_toolset import ApplicationIntegrationToolset
from google.adk.tools.mcp_tool.mcp_toolset import StreamableHTTPConnectionParams
from google.adk.tools.apihub_tool.clients.secret_client import SecretManagerClient
from google.adk.tools.openapi_tool.auth.auth_helpers import token_to_scheme_credential
from google.adk.tools.openapi_tool.auth.auth_helpers import dict_to_auth_scheme
from google.adk.auth import AuthCredential
from google.adk.auth import AuthCredentialTypes
from google.adk.auth import OAuth2Auth
from fastapi.openapi.models import OAuth2
from fastapi.openapi.models import OAuthFlowAuthorizationCode
from fastapi.openapi.models import OAuthFlows

load_dotenv()

PROJECT_ID=os.getenv("GOOGLE_CLOUD_PROJECT")
LOCATION=os.getenv("GOOGLE_CLOUD_LOCATION")
MCP_TOOLSET_URL=os.getenv("APIGEE_HOSTNAME")
API_HUB_LOCATION=f"projects/{PROJECT_ID}/locations/{LOCATION}/apis"
SECRET=f"projects/{PROJECT_ID}/secrets/cymbal-retail-apikey/versions/latest"
APP_SECRET=f"projects/{PROJECT_ID}/secrets/cymbal-agent-client-secret/versions/latest"
OAUTH_CLIENT_ID=os.getenv("OAUTH_CLIENT_ID")
AGENT_REDIRECT_URI=os.getenv("AGENT_REDIRECT_URI")


# # Get the credentials for the Cymbal Auto APIs
secret_manager_client = SecretManagerClient()
apikey_credential_str = secret_manager_client.get_secret(SECRET)
app_credential_str = secret_manager_client.get_secret(APP_SECRET) 
auth_scheme, auth_credential = token_to_scheme_credential("apikey", "header", "x-apikey", apikey_credential_str)

oauth2_scheme = OAuth2(
   flows=OAuthFlows(
      authorizationCode=OAuthFlowAuthorizationCode(
            authorizationUrl="https://accounts.google.com/o/oauth2/auth",
            tokenUrl="https://oauth2.googleapis.com/token",
            scopes={
                "https://www.googleapis.com/auth/cloud-platform" : "View and manage your data across Google Cloud Platform",
            }
      )
   )
)

oauth_credential = AuthCredential(
  auth_type=AuthCredentialTypes.OAUTH2,
  oauth2=OAuth2Auth(
      client_id=OAUTH_CLIENT_ID, 
      client_secret=app_credential_str,
      redirect_uri=AGENT_REDIRECT_URI
  )
)

TOOL_INSTR="""
        **Tool Definition: BigQuery Connector via Application Integration**

        This tool interacts with BigQuery dataset using an Application Integration Connector.
        It supports GET and LIST operations as defined for each entity.

        **Incident Getting:**

        If the user asks to get product details:
        Fetch all the products
"""

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
        url=f"https://{MCP_TOOLSET_URL}/mcp/v1/samples/adk-cymbal-retail/customers"
    ),
    errlog=None,
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)

# Products  ( Integration Connector ToolSet)
products = ApplicationIntegrationToolset(
    project=PROJECT_ID,
    location=LOCATION,
    connection="bq-products",
    entity_operations= {"products": ["GET","LIST"]},
    tool_name_prefix="tool-bq-products",
    tool_instructions=TOOL_INSTR,
    auth_scheme=oauth2_scheme,
    auth_credential=oauth_credential
)



