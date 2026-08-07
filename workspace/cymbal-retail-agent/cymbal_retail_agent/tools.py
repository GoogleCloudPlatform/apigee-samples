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

PROJECT_ID=os.getenv("GOOGLE_CLOUD_PROJECT")
LOCATION=os.getenv("GOOGLE_CLOUD_LOCATION")
API_HUB_LOCATION=f"projects/{PROJECT_ID}/locations/{LOCATION}/apis"

# REST based Orders API tool
orders_api_id="cymbal-orders-api"
orders = APIHubToolset(
    name="cymbal-orders-api",
    description="Retrieve customer orders API",
    apihub_resource_name=f"{API_HUB_LOCATION}/{orders_api_id}"
)

# Cymbal MCP tools to be added here
