
# Ingesting Azure APIM into Google Cloud API Hub

This guide provides a step-by-step workflow for ingesting API metadata from Azure API Management (APIM) into Google Cloud's API Hub. We will use a custom plugin and an Application Integration template to accomplish this.

## Prerequisites

To begin, ensure you have the following ready:

  * **Google Cloud Project:** A project with the API Hub service enabled.
  * **Azure Subscription:** An active subscription that includes your APIM instances.
  * **Permissions:** Your user account needs the following IAM roles in your Google Cloud project:
      * `Application Integration Invoker`
      * `Cloud Run Invoker`
      * `API Hub Admin`
  * **Azure Credentials:** The following details are required to connect to Azure APIM:
      * Client ID
      * Client Secret
      * Subscription ID
      * Tenant ID



## Setup Steps

### 1\. Configure API Hub Project Association

1.  In the Google Cloud console, navigate to **Apigee** \> **API hub** \> **Settings** \> **Project Associations**.
2.  Click **Attach Runtime Project**, select your project, and click **Confirm**.

-----

### 2\. Create a Service Account

1.  Go to **IAM & Admin** \> **Service Accounts**.
2.  Click **Create Service Account**, provide a name, and copy the generated **Email Address**. You'll need this later.
3.  Grant the following roles to the service account:
      * `Application Integration Invoker`
      * `Cloud Run Invoker`
      * `API Hub Admin`
4.  Click **Done**.

-----

### 3\. Create and Configure the Application Integration

1.  Navigate to **Application Integration**.
2.  Click **Create Integration**, give it a name, and click **Create**.
3.  On the integration page, click the three dots next to "FEEDBACK," select **Upload Integration**, and upload the provided JSON file.
4.  **Configure Authentication:**
      * Find the **API Trigger** named "Initiate ingestion to the HUB by calling Collect API."
      * In the **Authentication** section, click **Add new authentication profile**.
      * Enter a **Profile Name**, set the **Authentication type** to `Service account`, and paste the **Service Account Email** you copied earlier.
      * For **Scopes**, paste `https://www.googleapis.com/auth/cloud-platform`.
      * Click **Continue**.
5.  **Publish** the integration.

-----

### 4\. Create a Plugin

Run the following `curl` command to create the plugin. Remember to replace the placeholder values (`<YOUR_...>`) with your specific information.

```bash
curl -X POST -v \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
  "display_name": "Custom Azure Sync Plugin",
  "description": "A user-owned plugin to sync API data from Azure APIM using a Cloud Run service.",
  "actions_config": [
    {
      "id": "sync-metadata",
      "display_name": "Sync Azure Metadata",
      "description": "Syncs API metadata from Azure APIM via Cloud Run.",
      "trigger_mode": "API_HUB_SCHEDULE_TRIGGER"
    }
  ],
  "plugin_category": "API_GATEWAY",
  "ownership_type": "USER_OWNED",
  "hosting_service": {
    "service_uri": "https://<YOUR_CLOUD_RUN_SERVICE_URI>"
  },
  "config_template": {
    "auth_config_template": {
      "supportedAuthTypes": ["OAUTH2_CLIENT_CREDENTIALS"],
      "service_account": {
        "service_account": "<YOUR_SERVICE_ACCOUNT_EMAIL>"
      }
    },
    "additional_config_template": [
      {
        "id": "azureTenantId",
        "description": "The Active Directory Tenant ID for the Azure account.",
        "value_type": "STRING",
        "required": true
      },
      {
        "id": "azureSubscriptionId",
        "description": "The Azure Subscription ID containing the APIM instance.",
        "value_type": "STRING",
        "required": true
      },
      {
        "id": "integrationVersionId",
        "description": "Version ID for the Application Integration flow.",
        "value_type": "STRING",
        "required": false
      },
      {
        "id": "triggerId",
        "description": "Trigger ID.",
        "value_type": "STRING",
        "required": true
      },
      {
        "id": "integrationName",
        "description": "Name of the Application Integration flow.",
        "value_type": "STRING",
        "required": true
      },
      {
        "id": "integrationLocation",
        "description": "Region of the Application Integration flow.",
        "value_type": "STRING",
        "required": true
      }
    ]
  }
}' \
  "https://apihub.sandbox.googleapis.com/v1/projects/<YOUR_PROJECT_ID>/locations/<YOUR_REGION>/plugins?plugin_id=<YOUR_PLUGIN_ID>"
```

-----

### 5\. Create a Plugin Instance

1.  In the Google Cloud console, go to **Apigee** \> **API hub** \> **Settings** \> **Plugins**.
2.  Find your custom plugin and click **Create Instance**.
3.  Provide the required configuration details and click **Create**.
4.  **Retrieve the Instance ID:** After creation, right-click on the new instance's name and select **Inspect**. In the browser's developer tools, find the `name` attribute, which contains the full instance ID. It will look like this: `projects/<YOUR_PROJECT_ID>/locations/<YOUR_REGION>/plugins/<YOUR_PLUGIN_NAME>/instances/<YOUR_PLUGIN_INSTANCE_ID>`. Copy this ID.

-----

### 6\. Manually Configure Plugin Instance ID

1.  Go back to your **Application Integration** and open the request body for the **ingestion into API Hub trigger**.
2.  Replace the placeholder values for both the **Plugin Instance ID** and the **location** with the values you copied in the previous step.
3.  **Save** and **publish** the integration.

-----

### 7\. Run the Plugin

1.  Navigate back to **Apigee** \> **API hub** \> **Settings** \> **Plugins**.
2.  Find your plugin instance and click the **Execute** button to start the ingestion process.

## Known Limitations and Future Improvements

  * **Manual Plugin Instance ID Setup:** Currently, you must manually copy and paste the plugin instance ID into the Application Integration template. We plan to automate this step to make the setup faster and less prone to errors.
  * **Synchronous Ingestion:** The current integration is synchronous and may time out when ingesting a large number of APIs. A future update will introduce an asynchronous, serialized ingestion process to handle large datasets more reliably and avoid hitting API quotas.
  * **Improved Authentication:** We are exploring more robust authentication profiles to manage credentials more securely and flexibly than the current service account method.