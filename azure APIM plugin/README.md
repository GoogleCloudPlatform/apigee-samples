README: Ingesting Azure APIM into Google Cloud API Hub
This document outlines the complete workflow for ingesting API metadata from Azure APIM into Google Cloud API Hub using a custom plugin and an Application Integration template.
Prerequisites
Google Cloud Project: A Google Cloud project with API Hub enabled.
Azure Subscription: An active Azure subscription with APIM instances.
Permissions: You need appropriate permissions in your Google Cloud project to create service accounts, manage Application Integrations, and interact with API Hub. The service account you create should be granted the Application Integration Invoker, Cloud Run Invoker, and API Hub Admin roles.
Azure APIM Credentials: You'll need the client ID, client secret, subscription ID, and tenant ID to fetch data from Azure APIM.


Setup Steps1. Configure API Hub Project Association
In your Google Cloud console, navigate to Apigee > API hub > Settings > Project Associations.
Click on Attach Runtime Project and select the Google Cloud project you want to associate.
Click Confirm and verify the selected project is listed.


2. Create a Service Account
Navigate to IAM & Admin > Service Accounts in the Google Cloud console.
Click Create Service Account, provide a name, and copy the generated Email Address.
In the permissions section, grant the Application Integration Invoker, Cloud Run Invoker, and API Hub Admin roles.
Click Done.


3. Create and Configure the Application Integration
In your Google Cloud console, go to Application Integration.
Click Create Integration, give it a name, and click Create.
Upload JSON Configuration: On the integration page, click the three dots next to "FEEDBACK," select Upload Integration, and upload the JSON file.\
Configure Authentication:
Locate the API Trigger named "Initiate ingestion to the HUB by calling Collect API."
In the Authentication section, click Add new authentication profile.
Enter a Profile Name and set the Authentication type to Service account.
Paste the Service Account Email you copied earlier.


For Scopes, paste https://www.googleapis.com/auth/cloud-platform.
Click Continue.
Save the configuration and publish the integration.


4. Create a Plugin
This step involves using a curl command to create the plugin itself. Before running the command, you must replace the placeholders with your specific details.
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
        "description": "Version ID for the Application Integration flow .",
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
        "description": "Name of the Application Integration flow .",
        "value_type": "STRING",
        "required": true
      },
      {
        "id": "integrationLocation",
        "description": "Region of the Application Integration flow .",
        "value_type": "STRING",
        "required": true
      }
    ]
  }
}' \
  "https://apihub.sandbox.googleapis.com/v1/projects/<YOUR_PROJECT_ID>/locations/<YOUR_REGION>/plugins?plugin_id=<YOUR_PLUGIN_ID>"
5. Create a Plugin Instance
Navigate to Apigee > API hub > Settings > Plugins.
Click on the Create Instance button for the appropriate plugin type.
Provide the configuration details.
Click Create.
Retrieve Plugin Instance ID: After creating the instance, you'll need to retrieve its ID. Locate the newly created instance in the list, right-click on the plugin name, and select "Inspect." In your browser's developer tools, find the plugin instance ID within the name attribute. This ID will be in a format similar to: projects/<YOUR_PROJECT_ID>/locations/<YOUR_REGION>/plugins/<YOUR_PLUGIN_NAME>/instances/<YOUR_PLUGIN_INSTANCE_ID>. Copy this ID, as you'll need it later.
6. Manually Configure Plugin Instance ID
In the request body of the Application Integration, locate ingestion into API Hub trigger.
Replace the placeholder with the Plugin Instance ID you copied in Step 5.
Replace the placeholder for location with your project's location.
Save the configuration and publish the integration.


7. Run the Plugin 
From the Plugins section, find your plugin instance you just created.
Click on Execute to run the plugin instance. This will initiate the data ingestion from Azure APIM into API Hub.


Known Limitations
Manual Plugin Instance ID Setup: The current process requires you to manually copy and paste the plugin instance ID into the Application Integration template. This is a manual step that can be time-consuming and error-prone.
Synchronous Application Integration Template: The existing Application Integration template operates synchronously, which may lead to timeouts, especially with a large number of APIs or slow connections.


Future Considerations
We have identified the following areas for future improvement:
Automated Plugin Instance ID Embedding: The current process requires user to manually configure the plugin_instance ID in the Application Integration template. To streamline this, we plan to enhance the plugin creation process so that the plugin_instance ID is automatically embedded into the template. This will eliminate the need for a manual copy-and-paste step, making the setup much faster and more reliable.
Synchronous Ingestion: The existing Application Integration template is synchronous and can lead to timeouts when dealing with a large number of APIs. A future update will introduce an asynchronous serialized ingestion process to handle large datasets more robustly and avoid exceeding API quotas. The CCFE API has a quota of 20 requests per second for a single consumer project, which can be a problem with large data sets.
Improved Authentication: The current setup uses a service account directly for authentication. We are considering changing this to a more robust authentication profile to manage credentials more securely and flexibly.

