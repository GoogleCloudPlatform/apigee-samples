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
from fastapi.openapi.models import OAuth2, OAuthFlowAuthorizationCode, OAuthFlows
from google.adk.auth import AuthCredential, AuthCredentialTypes, OAuth2Auth
from google.adk.tools.apihub_tool.clients.secret_client import SecretManagerClient

PROJECT_ID=os.getenv("GOOGLE_CLOUD_PROJECT")
APIGEE_HOSTNAME = os.getenv("APIGEE_HOSTNAME")
SECRET1=f"projects/{PROJECT_ID}/secrets/cymbal-retail-client-id/versions/latest"
SECRET2=f"projects/{PROJECT_ID}/secrets/cymbal-retail-client-secret/versions/latest"

secret_manager_client = SecretManagerClient()
CLIENT_ID = secret_manager_client.get_secret(SECRET1)
CLIENT_SECRET = secret_manager_client.get_secret(SECRET2)

auth_scheme = OAuth2(
    flows=OAuthFlows(
        authorizationCode=OAuthFlowAuthorizationCode(
            authorizationUrl=f"https://{APIGEE_HOSTNAME}/authorize",
            tokenUrl=f"https://{APIGEE_HOSTNAME}/token",
            scopes={
                "customer": "Customer scope"    # This agent will request tokens with "customer" scope
            },
        )
    )
)

auth_credential = AuthCredential(
    auth_type=AuthCredentialTypes.OAUTH2,
    oauth2=OAuth2Auth(
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        redirect_uri="http://localhost:9000/callback"
    ),
)