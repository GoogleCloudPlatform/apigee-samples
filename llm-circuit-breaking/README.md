# **Serving LLM Traffic with Apigee**

## [Circuit Breaking Sample](llm_circuit_breaking.ipynb)

Circuit breaking with Apigee offers significant benefits for serving Large Language Models (LLMs) in Retrieval Augmented Generation (RAG) applications, particularly in preventing the dreaded `429` HTTP errors that arise from exceeding LLM endpoint quotas. By placing Apigee between the RAG application and LLM endpoints, users gain a robust mechanism for managing traffic distribution and graceful failure handling.

[![architecture](./images/llm-circuit-breaking.png)](llm_circuit_breaking.ipynb)

# Circuit Breaking Benefits

1. **Improved fault tolerance**: The multi-pool architecture, coupled with circuit breaking, provides inherent fault tolerance, ensuring that the RAG application remains operational even if one or more LLM endpoints fail or experience outages.
2. **Data-driven capacity planning**: Circuit breaking provides valuable insights into endpoint performance, allowing you to monitor and adjust capacity allocations based on actual traffic patterns and usage. This enables informed capacity planning and avoids unnecessary overprovisioning.
3. **Multitenancy**: Apigee provides a unified platform for managing and routing traffic to different LLM tenants, simplifying integration and reducing development effort.
4. **Centralized monitoring and analytics**: Apigee offers comprehensive monitoring and analytics capabilities, allowing for real-time insights into LLM endpoint performance, quota usage, and failover events. This enables proactive identification and resolution of issues, enhancing operational efficiency.

## Get started

Proceed to this [notebook](llm_circuit_breaking.ipynb) and follow the steps in the Setup and Testing sections.