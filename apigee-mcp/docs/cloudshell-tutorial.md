# Apigee Model Context Protocol (MCP) Server

This tutorial walks you through deploying and testing the Apigee Model Context Protocol (MCP) Server reference implementation. This solution demonstrates how Apigee can expose backend APIs as "tools" for an AI agent.

The solution consists of:
*   A stub **Customers API** backend (deployed as a Cloud Run service).
*   An Apigee API Proxy (`customers-api`) exposing the Customers API.
*   An Apigee API Proxy (`mcp-spec-tools`) that allows discovery of API Products and their OpenAPI specifications from Apigee API hub, and also issues OAuth tokens.
*   **Apigee MCP Server** (deployed as a Cloud Run service - `crm-mcp-service`) that uses `mcp-spec-tools` to find available APIs, generates corresponding tools for an AI agent, and executes them.
*   An Apigee API Proxy (`crm-mcp-proxy`) that exposes the Node.js MCP Server, secured with an API Key.
*   An Agent Development Kit (ADK) agent (run via a Jupyter notebook) that connects to the `crm-mcp-proxy` to interact with the available tools.

Let's get started!

---

## Prepare project dependencies

### 1. Select or confirm your Google Cloud project
<walkthrough-project-setup></walkthrough-project-setup>

### 2. Ensure you are authenticated in the Cloud Shell
```sh
gcloud auth login
```

### 3. Set the default project for gcloud commands
```sh
gcloud config set project <walkthrough-project-id/>
```

### 4. Enable the Services required to deploy this sample
```sh
gcloud services enable \
  logging.googleapis.com \
  monitoring.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  serviceusage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  aiplatform.googleapis.com \
  dataform.googleapis.com \
  --project <walkthrough-project-id/>
```
(Ensure your Apigee organization and Apigee API hub are provisioned in this project.)

## Set environment variables

### 1. Clone the Repository & Navigate to Project Directory
Make sure you are in your Cloud Shell home directory before cloning.
```sh
cd apigee-mcp
```

### 2. Create a Service Account for Apigee Proxies

This service account will be used by Apigee proxies to invoke the Cloud Run services. 
```sh 
export SERVICE_ACCOUNT_NAME="apigee-mcp-sa" 
gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
--display-name "Apigee MCP Service Account"
```
### 3. Grant the service account the Run Invoker role
```sh
gcloud projects add-iam-policy-binding <walkthrough-project-id/> \
--member="serviceAccount:${SERVICE_ACCOUNT_NAME}@<walkthrough-project-id/>.iam.gserviceaccount.com" \
--role="roles/run.invoker"
```
### 4. Grant the service account the Apigee API hub Admin role
```sh
gcloud projects add-iam-policy-binding <walkthrough-project-id/> \
--member="serviceAccount:${SERVICE_ACCOUNT_NAME}@<walkthrough-project-id/>.iam.gserviceaccount.com" \
--role="roles/apihub.admin"
```
After creating the service account, its email will be apigee-mcp-sa@<walkthrough-project-id/>.iam.gserviceaccount.com. You will use this for the SA_EMAIL variable in the next step.

### 4. Configure `env.sh`

Update the following placeholder values in<walkthrough-editor-open-file filePath="apigee-mcp/env.sh">env.sh</walkthrough-editor-open-file> with your specific configuration.

*   Set the <walkthrough-editor-select-regex filePath="apigee-mcp/env.sh" regex="PROJECT_ID_TO_SET">PROJECT</walkthrough-editor-select-regex>. The value should be <walkthrough-project-id/>.
*   Set the <walkthrough-editor-select-regex filePath="apigee-mcp/env.sh" regex="REGION_TO_SET">REGION</walkthrough-editor-select-regex> (e.g., `us-central1`).
*   Set the <walkthrough-editor-select-regex filePath="apigee-mcp/env.sh" regex="APIGEE_ENV_TO_SET">APIGEE_ENV</walkthrough-editor-select-regex> for your Apigee environment (e.g., `eval`).
*   Set the <walkthrough-editor-select-regex filePath="apigee-mcp/env.sh" regex="APIGEE_HOST_TO_SET">APIGEE_HOST</walkthrough-editor-select-regex> for your Apigee instance.
*   Set the <walkthrough-editor-select-regex filePath="apigee-mcp/env.sh" regex="SA_EMAIL_TO_SET">SA_EMAIL</walkthrough-editor-select-regex>. This service account will be used by Apigee proxies and needs `roles/run.invoker` on the deployed Cloud Run services. Use the email of the service account you just created: apigee-mcp-sa@<walkthrough-project-id/>.iam.gserviceaccount.com.

### 5. Set environment variables
Make the script executable and source it:
```sh
source ./env.sh
```

## Deploy the Solution
The `deploy-all.sh` script automates the deployment of all components.

### 1. Run the deployment script
```sh
./deploy-all.sh
```
This script will deploy Cloud Run services, Apigee proxies, API Products, and other necessary resources.

### 2. Review Deployment Output
At the end of the script execution, you will see output similar to this:
```sh
--------------------------------------------------
CRM Consumer Client ID: <SOME_API_KEY>
CRM Consumer Client Secret: <SOME_SECRET> # Note: Secret not used by notebook
Apigee Host: <YOUR_APIGEE_HOSTNAME>
Apigee MCP CRM endpoint: https://<YOUR_APIGEE_HOSTNAME>/crm-mcp-proxy/sse
--------------------------------------------------
All deployments and configurations complete.
```
**Important**: Note down the `CRM Consumer Client ID` and the `Apigee MCP CRM endpoint`. You will need these for testing.

## Test the Solution

You can now go to the Jupyter notebook to test the sample.

Open [`crm-agent-mcp`](https://github.com/GoogleCloudPlatform/apigee-samples/blob/main/apigee-mcp/notebooks/crm-agent-mcp.ipynb) in your preferred Jupyter environment.

**Note:** Before running the notebook, ensure you update the following placeholder values within it:
*   `GCP_PROJECT_ID`: Use the Project ID you configured in `env.sh` (variable `$PROJECT`).
*   `APIGEE_MCP_CRM_ENDPOINT`: Use the `Apigee MCP CRM endpoint` from the `deploy-all.sh` script output.
*   `CRM_TOOLS_API_KEY`: Use the `CRM Consumer Client ID` from the `deploy-all.sh` script output.

Follow the instructions within the notebook to execute the cells and observe the agent's interaction with the deployed tools.

## Clean Up

To avoid incurring charges, clean up the resources created during this tutorial.
Ensure your environment variables from `env.sh` are still set (if in a new terminal session, `source ./env.sh` again from the `apigee-mcp` directory).

### 1. Run the undeploy script
```sh
./undeploy-all.sh
```
This script will attempt to delete the Cloud Run services, Apigee artifacts, Apigee API hub resources, and other components deployed by the sample.

## Congratulations!

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

You've successfully deployed and tested the Apigee Model Context Protocol (MCP) Server reference implementation!

**Don't forget to clean up all deployed resources by running the `undeploy-all.sh` script if you haven't already.**
