# Cymbal Retail Agent

## Steps to deploy the ADK code to Agent Engine

1. Navigate to the `cymbal-retail-agent` directory if not already there
2. Run the following command `source .env`
3. Create an `.agent_engine_config.json` file by running the following command
```sh
echo "{
    \"service_account\": \"llm-cymbal-retail-agent@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com\"
}" > cymbal_retail_agent/.agent_engine_config.json
```
4. This should update the `.agent_engine_config.json` with your GCP project ID
5. To deploy to Agent Engine, run the following command
```sh
adk deploy agent_engine \
    --env_file=.env \
    --display_name=cymbal_retail_agent \
    cymbal_retail_agent
```
    NOTE: This will take a few minutes
6. Once this is complete, you should see the Agent Engine Resource Name something like `projects/{projectId}/locations/{location}/reasoningEngines/{reasoningEngineId}`, for example `projects/78901377646/locations/us-central1/reasoningEngines/76955126691298017281`. Take a note of the Reasoning Engine ID (`76955126691298017281` in this case).

## Steps to add this Agent to Gemini Enterprise

1. Navigate to the `cymbal-retail-agent` directory if not already there
2. Run the following command `source .env`
3. Export some additional variables by running
```sh
export PROJECT_NUMBER="$(gcloud projects describe $GOOGLE_CLOUD_PROJECT --format="value(projectNumber)")"
export TOKEN="$(gcloud auth print-access-token)"
export APP_NAME="gemini-enterprise"
export REASONING_ENGINE_ID="8410771371277156352" #input
export REASONING_ENGINE="projects/${PROJECT_NUMBER}/locations/${GOOGLE_CLOUD_LOCATION}/reasoningEngines/${REASONING_ENGINE_ID}"
```
4. Lets create our first app in Gemini Enterprise. Run the following curl in your terminal
```sh
curl -X POST "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUMBER}/locations/global/collections/default_collection/engines?engineId=${APP_NAME}" \
-H "X-Goog-User-Project: ${PROJECT_NUMBER}" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer ${TOKEN}" \
-d @- <<EOF
    {
        "displayName": "${APP_NAME}",
        "solutionType": "SOLUTION_TYPE_SEARCH",
        "searchEngineConfig": {
            "searchTier": "SEARCH_TIER_ENTERPRISE",
            "searchAddOns": [
                "SEARCH_ADD_ON_LLM"
            ]
        },
        "industryVertical": "GENERIC",
        "appType": "APP_TYPE_INTRANET"
    }
EOF
```
5. Lets add the deployed agent in Agent Engine to Gemini Enterprise. Run the following command
```sh
curl -X POST "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUMBER}/locations/global/collections/default_collection/engines/${APP_NAME}/assistants/default_assistant/agents" \
-H "X-Goog-User-Project: ${PROJECT_NUMBER}" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer ${TOKEN}" \
-d @- <<EOF
    {
        "displayName": "${APP_NAME}",
        "description": "Agent to retrieve customer order, customer profile, shipping information and process returns. This agent can delegate tasks to specialized sub-agents.",
        "adk_agent_definition": {
            "tool_settings": {
                "tool_description": "Agent to retrieve customer order, customer profile, shipping information and process returns. This agent can delegate tasks to specialized sub-agents."
            },
            "provisioned_reasoning_engine": {
                "reasoning_engine": "${REASONING_ENGINE}"
            }
        }
    }
EOF
```
6. You can now login to Gemini Enterprise on GCP console, and then access the App page. You should find the new agent.