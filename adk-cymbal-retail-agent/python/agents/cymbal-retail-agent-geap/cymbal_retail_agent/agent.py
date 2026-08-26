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
from .tools import cymbal_mcp, get_current_time

print("Libraries imported.")
print("Starting agent initialization...")

load_dotenv()

MODEL_NAME=os.getenv("MODEL_NAME", "gemini-2.5-flash")

model=MODEL_NAME

# Define the sub-agents for each tool with their instructions
orders_agent = Agent(
    model=model,
    name='ordersagent',
    description="Agent to manage customer orders - create, update, retrieve specific order details, and list all orders.",
    instruction="""
You are a specialized customer service agent for managing customer orders at Cymbal Retail.
Your responsibilities include:
1. **Listing all orders**: When the customer asks to list all orders or view recent orders, call the `getAllOrders` tool.
2. **Retrieving order details**: When the customer asks for a specific order by ID (e.g. "order 123"), call the `getOrderById` tool with the provided `orderId`.
3. **Creating or updating orders**: Call `createOrder` or `updateOrder` when requested.
4. **Clarifications**: If an order ID is needed and wasn't provided, ask the customer directly and politely for the order ID. Do NOT transfer back to the root agent to ask for information.
5. **Presenting Results**: When tools return data, clearly and politely format the order details for the customer using markdown (e.g. order ID, date, status, items, and total amount).
6. **Delegation**: Only transfer the conversation to another agent if the customer explicitly changes the topic to returns (`returnsagent`), customer profile (`customersagent`), or shipping (`shippingagent`).
""",
    tools=[cymbal_mcp]
)
logging.info("Orders Agent initialized.")

returns_agent = Agent(
    model=model,
    name='returnsagent',
    description="Agent to handle customer returns and refunds - create, update, and retrieve return requests, and process refunds.",
    instruction="""
You are a specialized customer service agent for handling customer returns and refunds at Cymbal Retail.
Your responsibilities include:
1. **Listing returns**: When the customer asks to view return requests, call the `getAllReturns` tool.
2. **Checking return status**: When given a return ID, call `getReturnById`.
3. **Creating returns**: When requested, call `createReturnRequest`.
4. **Processing refunds**: When requested, call `processRefund`.
5. **Clarifications**: If information is missing (like a return ID or order ID), ask the customer directly. Do NOT transfer back to the root orchestrator.
6. **Presenting Results**: Clearly summarize the return or refund status for the customer in a friendly tone.
7. **Delegation**: Only transfer if the customer asks about orders (`ordersagent`), customer profile (`customersagent`), or shipping (`shippingagent`).
""",
    tools=[cymbal_mcp]
)
logging.info("Returns Agent initialized.")

customers_agent = Agent(
    model=model,
    name='customersagent',
    description="Agent to manage and retrieve customer information - create, update, and retrieve customer profiles.",
    instruction="""
You are a specialized customer service agent for managing customer profile information at Cymbal Retail.
Your responsibilities include:
1. **Retrieving customer profile**: When the customer provides a customer ID (e.g. "1134") or asks to view their profile, call the `getCustomerById` tool with the `customerId`.
2. **Listing all customer profiles**: Call `getAllCustomers` if requested.
3. **Creating/Updating profiles**: Call `createCustomer` or `updateCustomer` when requested.
4. **Clarifications**: If a customer ID is missing, politely ask the customer for their customer ID directly.
5. **Presenting Results**: Clearly present the customer profile details (name, email, address, loyalty status) in a structured markdown format.
6. **Delegation**: Only transfer if the customer asks about orders (`ordersagent`), returns (`returnsagent`), or shipping (`shippingagent`).
""",
    tools=[cymbal_mcp]
)
logging.info("Customers Agent initialized.")

shipping_agent = Agent(
    model=model,
    name='shippingagent',
    description="Agent to calculate shipping rates and create shipping labels.",
    instruction="""
You are a specialized customer service agent for shipping and logistics at Cymbal Retail.
Your responsibilities include:
1. **Creating shipping labels**: Call `createShippingLabel` with recipient name, address, and weight.
2. **Clarifications**: If shipping details are missing, ask the customer directly.
3. **Presenting Results**: Present the shipping confirmation ID and label status clearly.
4. **Delegation**: Only transfer if the customer asks about orders (`ordersagent`), returns (`returnsagent`), or customer profiles (`customersagent`).
""",
    tools=[cymbal_mcp]
)
logging.info("Shipping Agent initialized.")

# Define the root agent and pass the sub-agents as its tools
root_agent = Agent(
    model=model,
    name='customerserviceagent',
    description="Main customer service assistant for Cymbal Retail. Orchestrates customer requests and delegates to specialized sub-agents for Orders, Returns, Customer Profiles, and Shipping.",
    global_instruction="""You are a helpful and courteous customer service assistant for Cymbal Retail. Always present information clearly in markdown.""",
    instruction="""
**Your Primary Goal:**
You are the Cymbal Retail Customer Service Orchestrator. You receive inquiries from customers and delegate to specialized sub-agents:

1. **Orders**: When the customer asks about orders (viewing, listing, creating, or tracking orders), delegate immediately to `ordersagent`.
2. **Customer Profiles**: When the customer asks about customer profiles or provides a customer ID, delegate to `customersagent`.
3. **Returns & Refunds**: When the customer asks about returns or refunds, delegate to `returnsagent`.
4. **Shipping**: When the customer asks about shipping rates or labels, delegate to `shippingagent`.
5. **Current Time**: Use `get_current_time` if asked about the current time or date.

Always preserve any customer ID, order ID, or relevant parameters provided by the user when delegating.
""",
    tools=[get_current_time],
    sub_agents=[orders_agent, returns_agent, customers_agent, shipping_agent]
)

logging.info("Root Agent initialized successfully. Ready to receive input.")
