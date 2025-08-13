# README: Ingesting Azure APIM into Google Cloud API Hub

This document outlines the steps to configure an Application Integration to fetch API metadata from Azure APIM and ingest it into Google Cloud API Hub.

***

### Prerequisites
* **Google Cloud Project**: You need a Google Cloud project with API Hub enabled.
* **Azure Subscription**: You need an active Azure subscription with APIM instances.
* **Permissions**: You need appropriate permissions in your Google Cloud project to create service accounts, manage Application Integrations, and interact with API Hub.
* **Azure APIM Credentials**: You will need the client ID, client secret, subscription ID, and tenant ID to fetch data from Azure APIM.

***

### Setup Steps
#### 1. Configure API Hub Project Association
1.  **Access Apigee API Hub Settings**: In your Google Cloud console, navigate to **Apigee** -> **API hub** -> **Settings**.
2.  **Attach Runtime Project**:
    * Choose **Project Associations**.
    * Click on **Attach Runtime Project**.
    * Select the Google Cloud project you want to associate with API Hub.
    * Click **Confirm**.
3.  **Verify Project Association**: You should see the selected project listed.

#### 2. Create a Plugin Instance
1.  **Access Plugins**: Go back to the **Settings** page in API Hub and select **Plugins**.
2.  **Create Apigee X and Hybrid Instance**:
    * Click on **Create Instance** for Apigee X and Hybrid.
    * Provide a descriptive **Display Name** for the instance.
    * Enter the **Source Project ID**.
    * Click **Create**.
3.  **Retrieve Plugin Instance ID**:
    * Locate the created instance under **Manage Instances**.
    * Right-click on the plugin name and select **Inspect**.
    * In the browser's developer tools, go to the **Elements** or **Inspect** tab.
    * Find the plugin instance ID within the **name** attribute (e.g., `projects/your-project-id/locations/your-region/plugins/system-apigee-x-and-hybrid/instances/your-plugin-instance-id`).
    * **Copy this ID**. You'll need it later.

#### 3. Create a Service Account
1.  **Navigate to IAM & Admin**: In your Google Cloud console, go to **IAM & Admin** -> **Service Accounts**.
2.  **Create Service Account**:
    * Click **Create Service Account**.
    * Enter a descriptive **Service Account Name**.
    * The Service Account ID will be automatically generated.
    * **Copy the generated Email Address**. You'll need this for authentication.
3.  **Grant Permissions**:
    * In the **Permissions** section, choose the **Cloud API Hub Admin** role.
    * Click **Done**.

#### 4. Create Application Integration
1.  **Access Application Integration**: In your Google Cloud console, go to **Application Integration**.
2.  **Create Integration**:
    * Click **Create Integration**.
    * Enter a descriptive **Integration Name**.
    * (Optional) Provide a **Description**.
    * Click **Create**.

#### 5. Upload JSON Configuration
1.  **Upload JSON**:
    * On the integration page, click the three dots next to **FEEDBACK**.
    * Select **Upload Integration**.
    * Upload the JSON file containing the integration configuration (as provided in the previous response).

#### 6. Configure Authentication
1.  **Access API Trigger**: In your Application Integration, locate the API Trigger you uploaded. It should be named something like "Initiate ingestion to the HUB by calling Collect API".
2.  **Configure Authentication Profile**:
    * Click on the **API Trigger**.
    * In the **Authentication** section, select **Authentication profile**.
    * Click **Add new authentication profile**.
    * Enter a **Profile Name** (e.g., "API Hub Ingestion Service Account").
    * Click **Continue**.
3.  **Select Service Account**:
    * Set **Authentication type** to **Service account**.
    * Paste the **Service Account Email** you copied earlier.
    * In **Scopes**, paste `https://www.googleapis.com/auth/cloud-platform`.
    * Click **Continue**.
4.  **Configure Request Body**:
    * In the request body, configure the `location` and `plugin_instance` values.
    * Replace the placeholder in `"location": "projects/ah-uapim-prov26/locations/us-west1"` with your actual project location (e.g., `"location": "projects/your-project-id/locations/your-region"`).
    * Replace the placeholder in `"plugin_instance": "projects/ah-uapim-prov26/locations/us-west1/plugins/system-apigee-x-and-hybrid/instances/62d09af8-2870-4c69-8be7-170a602c3218"` with the Plugin Instance ID you copied in Step 2.
    * Save the configuration.

#### 7. Test Integration with Azure APIM Details
1.  **Trigger Integration Test**:
    * Click **Test**.
    * A sidebar will open, showing a list of available triggers.
    * Choose the trigger named "Import data from Azure APIM to API Hub".
2.  **Enter Azure APIM Credentials**:
    * Input your Azure APIM credentials for `client id`, `client secret`, `subscription id`, and `tenant id`.
3.  **Run Test Integration**:
    * Click **Test Integration**.
    * This will initiate the process of fetching API details from Azure APIM and ingesting them into API Hub.

#### 8. Verify Ingestion
1.  **Check Integration Status**: Monitor the Application Integration execution logs for success or errors.
2.  **Access API Hub**: Navigate to **APIs** in your API Hub.
3.  **Verify APIs**: You should see the APIs fetched from Azure APIM listed in the API Hub.