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
from dotenv import load_dotenv
from fastapi.openapi.models import OAuth2, OAuthFlowAuthorizationCode, OAuthFlows
from google.adk.auth import AuthCredential, AuthCredentialTypes, OAuth2Auth
from google.adk.tools.apihub_tool.clients.secret_client import SecretManagerClient

load_dotenv()

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")
APIGEE_HOSTNAME = os.getenv("APIGEE_HOSTNAME")

secret_manager_client = SecretManagerClient()


def _resolve_secret(env_var_name: str, secret_ids: list[str]) -> str:
    env_val = os.getenv(env_var_name)
    if env_val:
        return env_val
    for secret_id in secret_ids:
        try:
            return secret_manager_client.get_secret(
                f"projects/{PROJECT_ID}/secrets/{secret_id}/versions/latest"
            )
        except Exception:
            continue
    return ""


CLIENT_ID = _resolve_secret(
    "CLIENT_ID", ["cymbal-retail-admin-client-id", "cymbal-retail-client-id"]
)
CLIENT_SECRET = _resolve_secret(
    "CLIENT_SECRET",
    ["cymbal-retail-admin-client-secret", "cymbal-retail-client-secret"],
)

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
        client_secret=CLIENT_SECRET
    ),
)