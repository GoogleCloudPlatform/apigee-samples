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

import warnings
warnings.filterwarnings("ignore")

import logging
logging.basicConfig(level=logging.ERROR)

from google.adk.agents import Agent
from .tools import cymbal_mcp
from google.adk.models.apigee_llm import ApigeeLlm
from google.adk.tools.apihub_tool.clients.secret_client import SecretManagerClient

print("Libraries imported.")
print("Starting agent initialization...")

load_dotenv()

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")
MODEL_NAME = os.getenv("MODEL_NAME", "gemma3:4b")
APIGEE_HOSTNAME = os.getenv("APIGEE_HOSTNAME")
APIGEE_LLM = os.getenv("APIGEE_LLM", "/v1/adk-retail-agent-llm-governance")
DEFAULT_MODEL_TIER = os.getenv("DEFAULT_MODEL_TIER", "local")
SECRET = f"projects/{PROJECT_ID}/secrets/cymbal-retail-client-id/versions/latest"

secret_manager_client = SecretManagerClient()
try:
    client_id = secret_manager_client.get_secret(SECRET)
except Exception:
    client_id = os.getenv("APIKEY", "")

# Configure Apigee LLM client with local Gemma tier routing
custom_headers = {"x-apikey": client_id}
if DEFAULT_MODEL_TIER:
    custom_headers["x-model-tier"] = DEFAULT_MODEL_TIER

model = ApigeeLlm(
    model=f"apigee/{MODEL_NAME}",
    proxy_url=f"https://{APIGEE_HOSTNAME}{APIGEE_LLM}",
    custom_headers=custom_headers
)


# Define the sub-agents for each tool with their instructions
orders_agent = Agent(
    model=model,
    name='ordersagent',
    description="Agent to manage customer orders - create, update, and retrieve order information.",
    instruction="""
You are a specialized agent for managing customer orders.
Your sole responsibilities include creating new orders, updating existing orders, and looking up existing orders. You will receive a request from the root agent.
Gather any additional information needed and then call the appropriate tool to process the request. 
Do not attempt to process any other type of request.
""",
    tools=[cymbal_mcp]
)
logging.info("Orders Agent initialized.")

returns_agent = Agent(
    model=model,
    name='returnsagent',
    description="Agent to handle customer returns and refunds - create, update, and retrieve return requests, and process refunds.",
    instruction="""
You are a specialized agent for handling customer returns and refunds.
Your sole responsibilities include processing return requests, checking the status of a refund, or providing return instructions. You will receive a request from the root agent.
Gather any additional information needed and then call the appropriate tool to process the request.
Do not attempt to process any other type of request.
""",
    tools=[cymbal_mcp]
)
logging.info("Returns Agent initialized.")

customers_agent = Agent(
    model=model,
    name='customersagent',
    description="Agent to manage and retrieve customer information - create, update, and retrieve customer profiles.",
    instruction="""
You are a specialized agent for managing customer profile information.
Your sole responsibilities include creating new customer profiles, updating existing customer profiles, and looking up existing customer profiles. You will receive a request from the root agent.
Gather any additional information needed and then call the appropriate tool to process the request.
Do not attempt to process any other type of request.
""",
    tools=[cymbal_mcp]
)
logging.info("Customers Agent initialized.")

shipping_agent = Agent(
    model=model,
    name='shippingagent',
    description="Agent to create shipping labels.",
    instruction="""
You are a specialized agent for creating customer shipping labels.
Your sole responsibilities include creating shipping labels. You will receive a request from the root agent.
Gather any additional information needed and then call the appropriate tool to process the request.
Do not attempt to process any other type of request.
""",
    tools=[cymbal_mcp]

)
logging.info("Shipping Agent initialized.")

# Define the root agent and pass the sub-agents as its tools
root_agent = Agent(
    model=model,
    name='customerserviceagent',
    description="Agent to retrieve customer order, customer profile, shipping information and process returns. This agent can delegate tasks to specialized sub-agents.",
    global_instruction="""You are a helpful virtual assistant for a retail company named Cymbal Retail. Always respond politely.""",
    instruction="""
**Your Primary Goal:**
You are the Cymbal Retail Agent. You are thr main orchestrator for the customer service team. You will receive requests from customers and will delegate tasks to specialized sub-agents.

1. Greet the user warmly and ask them how you can help.
2. If the user asks about related to an order, delegate to the orders_agent.
3. For questions about a customer's profile or general customer information, delegate to the customers_agent.
4. When the user asks about a return or refund, delegate to the returns_agent.
5. For shipping requests, delegate to the shipping_agent.

Throughout the conversation, maintain a friendly and helpful tone. If you need more information to complete a request, politely ask for it.
""",
    sub_agents=[orders_agent, returns_agent, customers_agent, shipping_agent]
)
logging.info("Root Agent initialized successfully. Ready to receive input.")
