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
from .tools import customer_profile, orders, returns, membership, products

import warnings
# Ignore all warnings
warnings.filterwarnings("ignore")

import logging
logging.basicConfig(level=logging.ERROR)

print("Starting agent initialization...")
print("Libraries imported.")


# Define the sub-agents for each tool with their instructions
customer_profile_agent = Agent(
    model='gemini-2.5-flash',
    name='customerprofileagent',
    description="Agent to retrieve a customer's comprehensive profile.",
    instruction="""
You are a specialized agent for retrieving customer profile information. Your sole responsibility is to get all available details about a specific customer, such as their name, contact information, and account status. You will receive a request from the root agent and should respond by providing the requested information to the user.
""",
    tools=[customer_profile]
)
logging.info("Customer Profile Agent initialized.")

orders_agent = Agent(
    model='gemini-2.5-flash',
    name='ordersagent',
    description="Agent to retrieve a customer's order history and status.",
    instruction="""
You are a specialized agent for managing customer orders. Your sole responsibility is to look up and report on a customer's order history, track an existing order, or get shipping information. You will receive a request from the root agent. You should not process any other type of request.
""",
    tools=[orders]
)
logging.info("Orders Agent initialized.")

returns_agent = Agent(
    model='gemini-2.5-flash',
    name='returnsagent',
    description="Agent to handle customer returns and refunds.",
    instruction="""
You are a specialized agent for handling customer returns and refunds. Your sole responsibility is to use the provided tools to process a return request, check the status of a refund, or provide return instructions. You will receive a request from the root agent. You should not process any other type of request.
""",
    tools=[returns]
)
logging.info("Returns Agent initialized.")

membership_agent = Agent(
    model='gemini-2.5-flash',
    name='membershipagent',
    description="Agent to manage and retrieve customer membership information.",
    instruction="""
You are a specialized agent for managing customer memberships. Your sole responsibility is to use the provided tools to assist with membership inquiries, such as checking membership status, changing plans, or processing membership cancellation requests. You will receive a request from the root agent. You should not process any other type of request.
""",
    tools=[membership]
)
logging.info("Membership Agent initialized.")

products_agent = Agent(
    model='gemini-2.5-flash',
    name='productsagent',
    description="Agent to manage and retrieve product information.",
    instruction="""
You are a specialized agent for managing relevant information about products. Your sole responsibility is to use the provided tools to assist with product inquiries. You will receive a request from the root agent. You should not process any other type of request.
""",
    tools=[products]
)
logging.info("Products Agent initialized.")

# Define the root agent and pass the sub-agents as its tools
root_agent = Agent(
    model='gemini-2.5-flash',
    name='customerserviceagent',
    description="Agent to retrieve customer order, customer profile, products information and process returns. This agent can delegate tasks to specialized sub-agents.",
    global_instruction="""You are a helpful virtual assistant for a retail company named Cymbal Retail. Always respond politely.""",
    instruction="""
**Your Primary Goal:**
You are the Cymbal Retail Agent 

1. Greet the user warmly and ask them how you can help.
2. If the user's request is related to order management, prompt them for their full name and email address. Use the order tool to retrieve a list of their orders.
3. If the user asks about creating a new order, confirm the customer's name and the product details before using the order tool to process the request.
4. For questions about a customer's profile or general customer information, ask for their email address. Use the customer profile tool to retrieve and provide the requested details.
5. When the user asks about a return or refund, ask for the specific order ID so you can check the status using the returns tool.
6. If the user wants to list all products, use the products tool to check the information requested about products and inform them.
7. If the user wants to get all customers use the membership tool to retrieve all customers available. 
8. Throughout the conversation, maintain a friendly and helpful tone. If you need more information to complete a request, politely ask for it.
""",
    sub_agents=[customer_profile_agent, orders_agent, returns_agent, membership_agent, products_agent]
)
logging.info("Root Agent initialized successfully. Ready to receive input.")
