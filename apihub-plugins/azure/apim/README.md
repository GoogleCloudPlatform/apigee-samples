<!--
 Copyright 2025 Google LLC

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->

# Sync API metadata from Azure API Management to Google Cloud Apigee API hub

This sample covers the one-time plugin instance setup that seeds API hub with
all existing APIs and supports on-demand re-syncs, plus an optional Azure
Function deployment that pushes individual APIM control-plane events to API hub
via Event Grid for continuous synchronization. Authentication for the real-time
Function to Google Cloud uses Workload Identity Federation — no long-lived
credentials are stored in Azure.

## Prerequisites

1.  **Azure:** a subscription with an APIM instance to synchronize and
    permission to create Microsoft Entra ID App Registrations and deploy ARM /
    Bicep templates (which create a Function App, storage account, App Service
    plan, user-assigned managed identity, and an Event Grid subscription).
2.  **Google Cloud:** an API hub-provisioned project. See
    [Provision API hub](https://cloud.google.com/apigee/docs/apihub/provision).
3.  **IAM on GCP side:** `roles/apihub.admin`,
    `roles/iam.workloadIdentityPoolAdmin`, `roles/iam.serviceAccountAdmin`,
    `roles/secretmanager.admin`, and `roles/resourcemanager.projectIamAdmin` (or
    `roles/owner`).
4.  **IAM on Azure side:** `Owner` or `Contributor` on the resource group
    holding the APIM (to deploy resources), plus `User Access Administrator` (to
    assign the APIM `Reader` role), and `Application Administrator` at the Entra
    tenant level (to create the App Registration).

## Values to gather before starting

Substitute these throughout the setup steps.

Placeholder                 | Where to find it
--------------------------- | ----------------
`<GCP_PROJECT_ID>`          | Your target API hub project
`<GCP_PROJECT_NUMBER>`      | Shown below the project ID in the GCP Console picker
`<GCP_LOCATION>`            | Region where the API hub instance is hosted (e.g., `us-west1`)
`<PLUGIN_INSTANCE_ID>`      | Auto-generated in [Step 3](#step-3-create-the-api-hub-plugin-instance); visible on the instance details page
`<AZURE_SUBSCRIPTION_ID>`   | Azure Portal → **Subscriptions**
`<AZURE_TENANT_ID>`         | Azure Portal → **Microsoft Entra ID → Overview**
`<AZURE_RESOURCE_GROUP>`    | The RG that already holds your APIM instance
`<AZURE_APIM_SERVICE>`      | Name of your APIM service
`<AZURE_APIM_REGION>`       | Region of your APIM (e.g., `eastus`, `westeurope`)
`<AZURE_APP_CLIENT_ID>`     | Created in [Step 1](#step-1-create-an-entra-app-registration-for-api-hub) (App Registration client id)
`<AZURE_APP_CLIENT_SECRET>` | Created in [Step 1](#step-1-create-an-entra-app-registration-for-api-hub) (shown once at secret creation)
`<AZURE_MI_OBJECT_ID>`      | Created in [Step 6](#step-6-deploy-the-bicep-template) (managed identity object id, on the Bicep deployment's Outputs tab)
`<SECRET_NAME>`             | You choose this in [Step 2](#step-2-store-the-azure-client-secret-in-google-secret-manager) (e.g., `apihub-azure-client-secret`)

## Setup Instructions

Follow these steps in order to configure the API hub plugin instance (Steps 1–3)
and then, optionally, layer real-time push on top (Steps 4–9).

### Step 1: Create an Entra App Registration for API hub

API hub uses OAuth2-style client credentials to read API metadata from Azure
APIM. Create a dedicated Entra App Registration with **read-only** access to
your APIM instance, and generate a client secret for it.

**1.1** In Azure Portal → **Microsoft Entra ID → App registrations → + New
registration**:

Field                   | Value
----------------------- | --------------------------------------------------
Name                    | `apihub-azure-apim` (or anything descriptive)
Supported account types | **Accounts in this organizational directory only**
Redirect URI            | Leave blank

Click **Register**.

**1.2** On the app's **Overview** page, copy the **Application (client) ID** —
this is `<AZURE_APP_CLIENT_ID>`.

**1.3** In the left nav → **Certificates & secrets → + New client secret**.

Field       | Value
----------- | -----------------------------------------------
Description | `apihub-plugin-instance`
Expires     | Pick per your rotation policy (e.g., 12 months)

Click **Add**, then copy the **Value** column immediately — this is
`<AZURE_APP_CLIENT_SECRET>` and it will not be shown again.

**1.4** Grant the App Registration's service principal the built-in **API
Management Service Reader Role** on the APIM instance. Azure Portal → open your
APIM service → left nav → **Access control (IAM) → + Add → Add role
assignment**.

Field            | Value
---------------- | -------------------------------------------------
Role             | **API Management Service Reader Role**
Assign access to | **User, group, or service principal**
Members          | Search for `apihub-azure-apim` and select the app

Click **Review + assign**.

> ⚠️ Use **API Management Service Reader Role**, not the built-in **Reader**
> role. Plain Reader grants ARM-level metadata visibility but not the APIM
> data-plane reads (`service/apis/read`, `service/apis/schemas/read`, …) the
> plugin needs; picking the wrong role produces a runtime `403
> AuthorizationFailed` from the plugin's `sync-metadata` action.

### Step 2: Store the Azure client secret in Google Secret Manager

The API hub plugin instance reads `<AZURE_APP_CLIENT_SECRET>` from a Secret
Manager secret. The application id is not sensitive and goes directly on the
plugin instance form.

**2.1** Enable the Secret Manager API (skip if it's already enabled):

```bash
gcloud services enable secretmanager.googleapis.com \
  --project=<GCP_PROJECT_ID>
```

**2.2** Create the secret and add its first version:

```bash
gcloud secrets create <SECRET_NAME> \
  --replication-policy=automatic \
  --project=<GCP_PROJECT_ID>

printf '%s' '<AZURE_APP_CLIENT_SECRET>' | \
  gcloud secrets versions add <SECRET_NAME> \
  --data-file=- \
  --project=<GCP_PROJECT_ID>
```

Use a descriptive `<SECRET_NAME>` such as `apihub-azure-client-secret`.

> ⚠️ `printf '%s'` (no trailing newline) is important. `echo` appends `\n` and
> produces an invalid client_secret at request time.

**2.3** Grant the API hub P4SA (per-product service account) read access to the
secret. The P4SA email format is:

```
service-<GCP_PROJECT_NUMBER>@gcp-sa-apihub.iam.gserviceaccount.com
```

Grant `roles/secretmanager.secretAccessor` on the secret:

```bash
gcloud secrets add-iam-policy-binding <SECRET_NAME> \
  --member="serviceAccount:service-<GCP_PROJECT_NUMBER>@gcp-sa-apihub.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=<GCP_PROJECT_ID>
```

> If the secret lives in a **different** GCP project than the API hub instance,
> run the binding in the project where the secret was created — the P4SA email
> always references the **API hub project's** number.

**2.4** Capture the full secret resource name — you will paste it into the
plugin instance form in Step 3:

```
projects/<GCP_PROJECT_ID>/secrets/<SECRET_NAME>/versions/latest
```

### Step 3: Create the API hub plugin instance

The Function publishes API metadata into a plugin instance of the built-in
`system-azure-apim` plugin. Create one instance per (Azure subscription, APIM
service) pair that you plan to sync.

**3.1** In your browser, open API hub in the Cloud console:

```
https://console.cloud.google.com/apigee/apihub/settings/plugins?project=<GCP_PROJECT_ID>
```

**3.2** In the **Google Cloud plugins** tab, click **Azure API Management**
(`system-azure-apim`) → **Create instance**.

**3.3** Fill in the form.

**Details:**

Field        | Value
------------ | ------------------------
Display name | Any human-readable label

**Configuration:**

Field                      | Value
-------------------------- | -------------------------
**azureTenantId**          | `<AZURE_TENANT_ID>`
**azureSubscriptionId**    | `<AZURE_SUBSCRIPTION_ID>`
**azureResourceGroupName** | `<AZURE_RESOURCE_GROUP>`
**azureApimServiceName**   | `<AZURE_APIM_SERVICE>`

**Authentication:**

Field                                        | Value
-------------------------------------------- | -----
**Auth type**                                | **OAuth 2.0 Client Credentials** (required)
**Client ID**                                | `<AZURE_APP_CLIENT_ID>` from Step 1
**Client secret** (Secret Manager reference) | `projects/<GCP_PROJECT_ID>/secrets/<SECRET_NAME>/versions/latest` from Step 2.4

**Sync frequency:**

| Field        | Value                                                       |
| ------------ | ----------------------------------------------------------- |
| **Schedule** | Runs automatically every **6 hours** by default. Adjust the |
:              : frequency if you want more or less frequent syncs.          :

**3.4** Click **Create instance** and wait for the status to become **Active**
(~30 seconds). Note the auto-generated **instance ID** shown on the details page
— this is `<PLUGIN_INSTANCE_ID>` for Step 6.

> **Initial sync happens automatically.** Once the plugin instance is Active,
> API hub kicks off a one-time backfill that discovers every existing APIM API
> in `<AZURE_APIM_SERVICE>` and registers it in API hub. This may take a few
> minutes depending on the number of APIs. Verify the results in the API hub
> Console under **APIs**.

**Keeping API hub in sync going forward.** After the initial backfill, you have
three ways to pick up APIs that are created or updated later:

1.  **Scheduled auto-sync (enabled by default).** The `sync-metadata` action
    runs every **6 hours** on its own — no action required. Adjust the frequency
    in the plugin instance's Actions section if you want more or less frequent
    syncs.
2.  **On-demand pull from API hub.** In the API hub Console, open the plugin
    instance and click **Run** to trigger a sync immediately. Useful right after
    a bulk deployment when you don't want to wait for the next scheduled run.
3.  **Real-time push from Azure (this sample).** Deploy the Function + Event
    Grid subscription described in Steps 4–8 below. Azure then pushes individual
    APIM control-plane events to API hub within ~30–60 seconds of each change.

The three options are complementary — you can enable real-time push later
without redoing the plugin instance setup.

### Step 4: Create a GCP service account for the Function

At
`https://console.cloud.google.com/iam-admin/serviceaccounts?project=<GCP_PROJECT_ID>`
click **+ Create Service Account**.

| Field                | Value                           |
| -------------------- | ------------------------------- |
| Service account name | `apihub-azure-onramp-sa`        |
| Role                 | **Cloud API hub Plugins Admin** |
:                      : (`roles/apihub.pluginAdmin`)    :

The full SA email will be
`apihub-azure-onramp-sa@<GCP_PROJECT_ID>.iam.gserviceaccount.com`.

### Step 5: Configure Workload Identity Federation

At
`https://console.cloud.google.com/iam-admin/workload-identity-pools?project=<GCP_PROJECT_ID>`
click **Create Pool**.

**5.1 Create pool:**

Field   | Value
------- | --------------------------
Name    | `apihub-azure-onramp-pool`
Enabled | Checked

**5.2 Add provider:**

Field             | Value
----------------- | ---------------------------------------------
Provider          | **OpenID Connect (OIDC)**
Provider name     | `azure-apim-oidc`
Issuer (URL)      | `https://sts.windows.net/<AZURE_TENANT_ID>/`
Allowed audiences | `api://<AZURE_APP_CLIENT_ID>` (from Step 1.2)

Leave the "Configure provider attributes" step at its defaults.

**5.3 Grant access** — pick **"Grant access using service account
impersonation"** (not federated identities), select the `apihub-azure-onramp-sa`
SA created in Step 4, and add a principal with:

| Attribute name | Attribute value                                           |
| -------------- | --------------------------------------------------------- |
| `subject`      | `<AZURE_MI_OBJECT_ID>` (from Step 6 — leave blank for now |
:                : and add after Bicep deploy)                               :

The grant can be added later without deleting the pool.

**5.4 Build the WIF audience string** (needed in Step 6):

```
//iam.googleapis.com/projects/<GCP_PROJECT_NUMBER>/locations/global/workloadIdentityPools/apihub-azure-onramp-pool/providers/azure-apim-oidc
```

### Step 6: Deploy the Bicep template

In Azure Portal → **Deploy a custom template** (search "Deploy a custom
template" in the top search bar).

-   Click **Build your own template in the editor**.
-   Delete the placeholder content and paste the contents of `main.bicep` from
    this directory. The Portal accepts Bicep directly.
-   Click **Save**.
-   **Subscription:** `<AZURE_SUBSCRIPTION_ID>`
-   **Resource group:** `<AZURE_RESOURCE_GROUP>` (the RG holding your APIM)
-   **Region:** `<AZURE_APIM_REGION>` (must match the APIM region)
-   **Parameters:**

    | Parameter     | Value                                                    |
    | ------------- | -------------------------------------------------------- |
    | apimName      | `<AZURE_APIM_SERVICE>`                                   |
    | location      | `<AZURE_APIM_REGION>`                                    |
    | appId         | `<AZURE_APP_CLIENT_ID>` from Step 1                      |
    | gcpProject    | `<GCP_PROJECT_ID>`                                       |
    | projectNumber | `<GCP_PROJECT_NUMBER>`                                   |
    | gcpLocation   | `<GCP_LOCATION>`                                         |
    | instanceId    | `<PLUGIN_INSTANCE_ID>` from Step 3.4                     |
    | poolId        | `apihub-azure-onramp-pool` (from Step 5.1 — override if  |
    :               : you named your WIF pool differently)                     :
    | providerId    | `azure-apim-oidc` (from Step 5.2 — override if you named |
    :               : your OIDC provider differently)                          :
    | saName        | `apihub-azure-onramp-sa` (from Step 4 — override if you  |
    :               : named your GCP service account differently)              :

    Leave the remaining parameters (`apihubHost`, `pluginId`,
    `deploymentTypeId`, `apimApiVersion`, `tags`, `enableAppInsights`) at their
    defaults.

-   Click **Review + create → Create**.

Wait for status **Your deployment is complete** (~2 minutes).

**6.5** After deployment, note the output values on the deployment's **Outputs**
tab. Copy `uamiPrincipalId` — this is `<AZURE_MI_OBJECT_ID>`.

**6.6** Complete the WIF principal binding you deferred in Step 5.3: go back to
the Workload Identity Pool, click into the `apihub-azure-onramp-sa` grant, and
add the principal with `subject` = `<AZURE_MI_OBJECT_ID>`.

**6.7** Also add a **federated credential** to the App Registration from Step 1
so the Azure Function's managed identity can obtain a token for
`api://<AZURE_APP_CLIENT_ID>`. Azure Portal → **Entra ID → App registrations →
apihub-azure-apim → Certificates & secrets → Federated credentials → + Add
credential**.

| Field            | Value                                              |
| ---------------- | -------------------------------------------------- |
| Scenario         | **Managed identity as federated identity**         |
| Managed identity | Pick the `id-apihub-onramp` user-assigned identity |
:                  : created by Bicep in Step 6                         :
| Name             | `apihub-onramp-mi`                                 |
| Audience         | `api://AzureADTokenExchange` (default)             |

Click **Add**.

### Step 7: Publish the Function code

The Bicep template creates the Function App infrastructure but leaves the
function code slot empty.

Prerequisites: [Azure Functions Core Tools][func-tools] and the
[Azure CLI][az-cli] installed. Both are pre-installed in Azure Cloud Shell.

Clone this sample (if you haven't already) and run:

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/apihub-plugins/azure/apim

az login  # if not already authenticated
func azure functionapp publish func-apihub-onramp --javascript
```

Wait for **"Deployment successful"** (~1–2 minutes). The function
`onrampApimSync` is now live.

[func-tools]: https://learn.microsoft.com/azure/azure-functions/functions-run-local
[az-cli]: https://learn.microsoft.com/cli/azure/install-azure-cli

### Step 8: Create the Event Grid subscription

Azure Portal → open the **APIM service** `<AZURE_APIM_SERVICE>` → left nav →
**Events → + Event Subscription**.

| Field                 | Value                                 |
| --------------------- | ------------------------------------- |
| Name                  | `apihub-onramp-sync`                  |
| Event Schema          | **Event Grid Schema**                 |
| Filter to Event Types | Uncheck all except                    |
:                       : `Microsoft.ApiManagement.APICreated`, :
:                       : `Microsoft.ApiManagement.APIUpdated`, :
:                       : `Microsoft.ApiManagement.APIDeleted`  :
| Endpoint Type         | **Azure Function**                    |
| Endpoint              | Click **Select an endpoint** → pick   |
:                       : the `func-apihub-onramp` Function App :
:                       : → function `onrampApimSync`           :

Click **Create**. Wait ~30 seconds for provisioning.

### Step 9: Verify

Create or edit any API in your APIM instance (APIM Portal → **APIs → + Add API →
HTTP** or **OpenAPI**). Within 30–60 seconds:

-   The Function invocation appears in **Function App → Functions →
    onrampApimSync → Monitor** with `Success` status.
-   The API shows up in API hub at
    `https://console.cloud.google.com/apigee/apihub?project=<GCP_PROJECT_ID>`
    with the APIM subscription/service/api path as its `original_id`.

If the invocation fails, check the **Result** field on the Monitor page for the
exception message. Common causes:

-   WIF principal binding missing on the SA (revisit Step 6.6 with the
    `<AZURE_MI_OBJECT_ID>` from Step 6.5).
-   Federated credential missing on the App Registration (revisit Step 6.7).
-   IAM Credentials API not enabled (`gcloud services enable
    iamcredentials.googleapis.com --project=<GCP_PROJECT_ID>`).
-   Service account missing `roles/apihub.pluginAdmin` on the API hub project
    (revisit Step 4).

## Files Included

-   `main.bicep`: Azure infrastructure template (Function App + storage + App
    Service plan + user-assigned managed identity + APIM Reader role
    assignment + optional Application Insights).
-   `src/functions/onrampApimSync.js`: The Event Grid-triggered sync function
    (Node.js 20).
-   `host.json`, `package.json`: Azure Functions runtime configuration.

## Disclaimer

This is a sample integration and may require modifications to fit your specific
security and operational requirements.
