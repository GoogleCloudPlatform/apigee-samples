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

from google.adk.auth import auth_preprocessor
from google.adk.auth.auth_handler import AuthHandler

original_store_auth = auth_preprocessor._store_auth_and_collect_resume_targets
async def patched_store_auth(events, auth_fc_ids, auth_responses, state):
    logging.error(f"[PATCH PREPROCESSOR] Initial state keys: {list(state.keys()) if hasattr(state, 'keys') else 'no keys'}")
    logging.error(f"[PATCH PREPROCESSOR] auth_fc_ids: {auth_fc_ids}, auth_responses: {auth_responses}")
    result = await original_store_auth(events, auth_fc_ids, auth_responses, state)
    logging.error(f"[PATCH PREPROCESSOR] Final state keys: {list(state.keys()) if hasattr(state, 'keys') else 'no keys'}")
    return result

auth_preprocessor._store_auth_and_collect_resume_targets = patched_store_auth

original_parse_and_store = AuthHandler.parse_and_store_auth_response
async def patched_parse_and_store(self, state):
    logging.error(f"[PATCH AUTH_HANDLER] Writing credential for key: {self.auth_config.credential_key}")
    await original_parse_and_store(self, state)
    credential_key = "temp:" + self.auth_config.credential_key
    val = state.get(credential_key) if hasattr(state, "get") else state[credential_key]
    logging.error(f"[PATCH AUTH_HANDLER] Done writing. Key: {credential_key}, Value: {val}")

AuthHandler.parse_and_store_auth_response = patched_parse_and_store

from google.adk.auth.credential_service.session_state_credential_service import SessionStateCredentialService
from google.adk.auth.auth_credential import AuthCredential

original_load_credential = SessionStateCredentialService.load_credential
async def patched_load_credential(self, auth_config, callback_context):
    cred = await original_load_credential(self, auth_config, callback_context)
    if cred:
        logging.error(f"[PATCH CREDENTIAL_SERVICE] Key {auth_config.credential_key} loaded. Type: {type(cred)}, Val: {cred}")
        if isinstance(cred, str):
            import json
            try:
                cred = json.loads(cred)
                logging.error(f"[PATCH CREDENTIAL_SERVICE] Parsed JSON string to dict")
            except Exception as e:
                logging.error(f"[PATCH CREDENTIAL_SERVICE] Failed to parse JSON string: {e}")
        if isinstance(cred, dict):
            logging.error(f"[PATCH CREDENTIAL_SERVICE] Deserializing dict to AuthCredential for key {auth_config.credential_key}")
            cred = AuthCredential.model_validate(cred)
    return cred

SessionStateCredentialService.load_credential = patched_load_credential

print("Libraries imported.")
print("Starting agent initialization...")

load_dotenv()

MODEL_NAME=os.getenv("MODEL_NAME", "gemini-2.5-flash")

model=MODEL_NAME

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

async def restore_credentials(callback_context):
    from google.adk.auth.auth_credential import AuthCredential
    import json
    state = callback_context.state
    logging.error(f"[DEBUG RESTORE] Initial state keys: {list(state.to_dict().keys())}")
    for key, value in list(state.to_dict().items()):
        if key.startswith("persistent_auth:"):
            temp_key = key.replace("persistent_auth:", "temp:")
            logging.error(f"[DEBUG RESTORE] Key: {key}, Type: {type(value)}, Val: {value}")
            if isinstance(value, str):
                try:
                    value = json.loads(value)
                    logging.error(f"[DEBUG RESTORE] Parsed JSON string to dict")
                except Exception as e:
                    logging.error(f"[DEBUG RESTORE] Failed to parse JSON string: {e}")
            if isinstance(value, dict):
                logging.error(f"[DEBUG RESTORE] Deserializing dict value for {key}")
                value = AuthCredential.model_validate(value)
            state[temp_key] = value
            logging.error(f"[DEBUG RESTORE] Restored key {key} to {temp_key}")
    logging.error(f"[DEBUG RESTORE] Final state keys: {list(state.to_dict().keys())}")

async def persist_credentials(callback_context):
    from google.genai import types
    state = callback_context.state
    has_changes = False
    logging.error(f"[DEBUG PERSIST] Initial state keys: {list(state.to_dict().keys())}")
    for key, value in list(state.to_dict().items()):
        if key.startswith("temp:adk_"):
            persist_key = key.replace("temp:", "persistent_auth:")
            state[persist_key] = value
            has_changes = True
            logging.error(f"[DEBUG PERSIST] Persisted key {key} to {persist_key}")
    logging.error(f"[DEBUG PERSIST] Final state keys: {list(state.to_dict().keys())}")
    if has_changes:
        return types.Content(role="model", parts=[types.Part(text="")])
    return None

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
    sub_agents=[orders_agent, returns_agent, customers_agent, shipping_agent],
    before_agent_callback=restore_credentials,
    after_agent_callback=persist_credentials,
)

# Apply credentials callbacks to all sub-agents so they persist/restore auth state when resumed directly
for agent in [orders_agent, returns_agent, customers_agent, shipping_agent]:
    agent.before_agent_callback = restore_credentials
    agent.after_agent_callback = persist_credentials

logging.info("Root Agent initialized successfully. Ready to receive input.")
