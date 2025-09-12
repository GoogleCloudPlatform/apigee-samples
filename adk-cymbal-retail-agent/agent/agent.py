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

from google.adk.agents import Agent
from .prompts import ROOT_AGENT_INSTR
from .tools import customer_profile
from .tools import orders
from .tools import returns
from .tools import membership


import warnings
# Ignore all warnings
warnings.filterwarnings("ignore")

import logging
logging.basicConfig(level=logging.ERROR)

print("Libraries imported.")

root_agent = Agent(
    model='gemini-2.5-flash',
    name='customerserviceagent',
    description="Agent to retrieve customer order, customer profile, inventory and process returns and refunds",
    instruction=ROOT_AGENT_INSTR,
    tools=[customer_profile, orders, returns, membership]

)
