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
from google.adk.auth import AuthCredential, AuthCredentialTypes
from google.adk.auth.credential_manager import CredentialManager
from google.adk.integrations.agent_identity import GcpAuthProvider, GcpAuthProviderScheme

# Use GCP Auth Manager to obtain tokens
CredentialManager.register_auth_provider(GcpAuthProvider())
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")
if not PROJECT_ID:
    raise ValueError("GOOGLE_CLOUD_PROJECT environment variable is not set")
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION")
CONNECTOR_NAME = "idp-connector"
CONTINUE_URI = os.getenv("OAUTH_CALLBACK_URL", "http://127.0.0.1:9000/callback")

# Configure the Auth provider using the Google Cloud Agent Identity connector
auth_scheme = GcpAuthProviderScheme(
    name=f"projects/{PROJECT_ID}/locations/{LOCATION}/connectors/{CONNECTOR_NAME}",
    scopes=["customer"],  # This agent will request tokens with "customer" scope
    continue_uri=CONTINUE_URI
)

auth_credential = None