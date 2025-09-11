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
