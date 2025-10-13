# Azure API Management to Google Cloud API Hub Integration

This sample provides an Application Integration template and scripts to synchronize API metadata from Azure API Management (APIM) to Google Cloud API Hub.

## Prerequisites

1.  **Azure:**
    *   An Azure Subscription with an active API Management instance.
    *   Azure CLI (`az`) installed and authenticated. You can install it from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
2.  **Google Cloud:**
    *   A Google Cloud Project with API Hub provisioned. See [Provision API Hub](https://cloud.google.com/apigee/docs/apihub/provision).
    *   Google Cloud SDK (`gcloud`) installed and authenticated. You can install it from [here](https://cloud.google.com/sdk/docs/install).
    *   The following Google Cloud APIs Enabled in your project:
        *   `apihub.googleapis.com` (API Hub API)
        *   `integrations.googleapis.com` (Application Integration API)
        *   `secretmanager.googleapis.com` (Secret Manager API)
            You can enable these using the `gcp_setup.sh` script or manually in the Cloud Console.
3.  **Tools:**
    *   `jq`: A lightweight and flexible command-line JSON processor. Install it from [here](https://stedolan.github.io/jq/download/).
    *   `curl`: A command-line tool for transferring data with URLs.
    *   Bash shell environment.

## Setup Instructions

Follow these steps in order to set up and deploy the integration.

### Step 1: Configure Azure Resources

This step involves running a script to set up an Azure Active Directory application and grant it the necessary permissions to read from your APIM instance.

1.  Navigate to the directory containing the scripts.
2.  Update the env.sh file with appropriate values. Then execute the following command:
    ```bash
    source env.sh
    ```
3.  Run the script:
    ```bash
    ./azure_setup.sh
    ```
4.  **Important:** At the end of the script, carefully note down the outputted `AZURE_CLIENT_ID` and `AZURE_CLIENT_SECRET`. The secret will not be shown again. Paste those values in the env.sh file and run `source env.sh` again

### Step 2: Configure Google Cloud Resources

This script configures the necessary Google Cloud resources, including a service account, IAM permissions, and creating a plugin `azure-apim-plugin` with an instance `instance` in API hub.

Run the script:
```bash
./gcp_setup.sh
```

### Step 3: Deploy the Application Integration

This script deploys the `azure_ip_template.json` workflow to your Google Cloud project's Application Integration service.

Run the script:
```bash
./deploy_integration.sh
```

### Step 4: Execute the Integration

To run the synchronization process, you will execute the deployed integration.

Run the script:
```bash
./execute_integration.sh
```

Upon successful triggering, the script will indicate that the execution has started. You can monitor the detailed logs and status within the Application Integration section of the Google Cloud Console.

## Files Included

*   `azure_ip_template.json`: The core Application Integration workflow definition.
*   `azure_setup.sh`: Script to configure Azure resources.
*   `gcp_setup.sh`: Script to configure GCP resources.
*   `deploy_integration.sh`: Script to deploy the integration template.
*   `execute_integration.sh`: Script to trigger the integration.
*   `README.md`: This file.

## Disclaimer

This is a sample integration and may require modifications to fit your specific security and operational requirements.
