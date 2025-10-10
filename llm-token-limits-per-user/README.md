# **LLM Serving with Apigee**

## [Token Limits Per User Sample](llm_token_limits_per_user.ipynb)

Every interaction with an LLM consumes tokens, therefore, LLM token management plays a crucial role in maintaining platform-level control and visibility over the consumption of tokens across LLM providers and consumers.

Apigee's API Products, when applied to token consumption, allows you to effectively manage token usage by setting limits on the number of tokens consumed per LLM consumer. This policy leverages the token usage metrics provided by an LLM, enabling real-time monitoring and enforcement of limits.

One can measure the token consumption per client app (let's say, an AI Agent). Another way though, would be limiting and counting the token usage according to the end user that uses the client app. A single AI Agent, for instance, can have multiple end users (for example, human users interacting with an AI chatbot application) we might want to also track and control this usage.

This requires not only a client_id (that would identify the client app) but some form of user ID (maybe coming from an ID Token) and this information needs to reach Apigee for such control.

[![architecture](./images/ai-product.png)](llm_token_limits_per_user.ipynb)

### Benefits Token Limits with AI Products

Creating Product tiers within Apigee allows for differentiated token quotas based for each consumer. This enables you to:

- **Control token allocation**: Prioritize resources for high-priority consumers by allocating higher token quotas to their tiers. This will also help to manage platform-wide token budgets across multiple LLM providers.
- **Tiered AI products**: By utilizing product tiers with granular token quotas, Apigee effectively manages LLM and empowers AI platform teams to manage costs and provide a multi-tenant platform experience. With Apigee's flexibility, we can have the rates to be "counted" per user or per app. This sample explores the per user strategy.

### Get started

Proceed to this [notebook](llm_token_limits_per_user.ipynb) and follow the steps in the Setup and Testing sections.
