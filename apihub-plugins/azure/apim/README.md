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
5.  **Consumption Plan (Y1) quota:** the Function App in
    [Step 6](#step-6-deploy-the-bicep-template) runs on the Consumption Plan
    (Y1) SKU. If the subscription has `0` Y1 quota in the target region, the
    deploy fails preflight with `SubscriptionIsOverQuotaForSku`. Check **Quotas
    → App Service** for your region before starting, and see
    [Step 6.0](#step-6-deploy-the-bicep-template) for how to request quota.

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
this is `<AZURE_APP_CLIENT_ID>`. Then set an **Application ID URI**: on the same
Overview page, click **Add an Application ID URI → Set**, keep the default value
`api://<AZURE_APP_CLIENT_ID>`, and **Save**. Without this URI Microsoft Entra
will refuse to issue tokens with that audience, and the Function fails silently
at `AADSTS500011` when it tries to fetch a subject token for WIF.

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

**2.1** Enable the Secret Manager, IAM Credentials, and Security Token Service
APIs (skip whichever are already enabled). All three are required — Secret
Manager holds the Azure client secret, and IAM Credentials + STS are used by the
real-time push in Steps 4-9 for the Workload Identity Federation token exchange.
Missing IAM Credentials or STS surfaces later as an `impersonation HTTP 403`
from the Function:

```bash
gcloud services enable \
    secretmanager.googleapis.com \
    iamcredentials.googleapis.com \
    sts.googleapis.com \
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
projects/<GCP_PROJECT_ID>/secrets/<SECRET_NAME>/versions/<VERSION_NUMBER>
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
**Client secret** (Secret Manager reference) | `projects/<GCP_PROJECT_ID>/secrets/<SECRET_NAME>/versions/<VERSION_NUMBER>` from Step 2.4

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

Under **Configure provider attributes**, verify that `google.subject` is mapped
to `assertion.sub`. The default should already show this, but the Console
occasionally clears the field and rejects the pool at Save with `attribute
mapping is required`; if the input is empty, type `assertion.sub` manually.

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

Deploy via **Azure Cloud Shell** (browser-based; no local tooling required). The
Portal's "Build your own template in the editor" pane accepts only ARM JSON, but
`az deployment` in Cloud Shell transpiles Bicep on the fly when you pass a
`.bicep` file directly.

> If the deploy fails with `SubscriptionIsOverQuotaForSku: Current Limit (Y1
> VMs): 0`, the subscription has no Consumption Plan (Y1) quota in this region.
> Follow Step 6.0 below to request it.

**6.0** (Only if the deploy failed with `SubscriptionIsOverQuotaForSku`.)
Request Y1 quota explicitly: in the Azure Portal, search for **Quotas**, select
**App Service** (older tenants list it under **Compute**), filter by
**Provider = Microsoft.Web** and **Region = `<AZURE_APIM_REGION>`**, find
**Dynamic App Service Plans**, tick the row, and submit **New Quota Request**
for `1` (or higher for headroom). Small requests typically resolve in a few
hours; worst case ~1 business day.

**6.1** In the Azure Portal, click the Cloud Shell icon (`>_`) in the top nav
bar and pick **Bash**. On first use, accept the default when prompted to create
a Cloud Shell storage account.

**6.2** In Cloud Shell, run `code main.bicep`. A VS Code-style editor opens in
the upper pane. Paste the contents of `main.bicep` from this directory, save
with **Ctrl+S**, then close with **Ctrl+Q**.

**6.3** Deploy.

> ⚠️ Cloud Shell defaults to **PowerShell** on returning sessions, and the
> multi-line ``\` continuations below are Bash syntax — pasting them into
> a``PS>`prompt fails with`ParserError: Missing expression after unary operator
> '-'`. If your prompt is `PS>`, type `bash`and press Enter to switch; the
> prompt should become`$`(or`user@Azure:~$`).

```bash
az deployment group create \
  --resource-group <AZURE_RESOURCE_GROUP> \
  --template-file main.bicep \
  --parameters \
      apimName=<AZURE_APIM_SERVICE> \
      location=<AZURE_APIM_REGION> \
      appId=<AZURE_APP_CLIENT_ID> \
      gcpProject=<GCP_PROJECT_ID> \
      projectNumber=<GCP_PROJECT_NUMBER> \
      gcpLocation=<GCP_LOCATION> \
      instanceId=<PLUGIN_INSTANCE_ID>
```

Override `poolId`, `providerId`, or `saName` only if you named those resources
differently in Steps 4-5 (defaults: `apihub-azure-onramp-pool`,
`azure-apim-oidc`, `apihub-azure-onramp-sa`). Leave `apihubHost`, `pluginId`,
`deploymentTypeId`, `apimApiVersion`, `tags`, and `enableAppInsights` at their
defaults.

Wait for the CLI to print `"provisioningState": "Succeeded"` (~2 minutes). The
deployment is also visible in the Portal under the resource group's
**Deployments** blade.

> If Cloud Shell is unavailable in your tenant, transpile the Bicep to ARM JSON
> on a workstation with Azure CLI installed (`az bicep build --file main.bicep`
> emits `main.json`), then in the Portal use **Deploy a custom template → Build
> your own template in the editor → Load file** and pick `main.json`. Fill the
> parameters listed above via the Portal form.

**6.4** After deployment, note the output values on the deployment's **Outputs**
tab. Copy `uamiPrincipalId` — this is `<AZURE_MI_OBJECT_ID>`.

**6.5** Complete the WIF principal binding you deferred in Step 5.3: go back to
the Workload Identity Pool, click into the `apihub-azure-onramp-sa` grant, and
add the principal with `subject` = `<AZURE_MI_OBJECT_ID>`.

**6.6** Also add a **federated credential** to the App Registration from Step 1
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

The Function App name is `func-apihub-onramp-<hash>`, where `<hash>` is a
6-character suffix derived from the resource group ID (so the name is globally
unique — Function Apps become `*.azurewebsites.net` DNS entries). Grab the exact
name from the Bicep output — read it directly from Step 6.4's outputs tab
(`functionAppName`), or from Cloud Shell:

```bash
FUNC=$(az deployment group show \
  --resource-group <AZURE_RESOURCE_GROUP> --name main \
  --query "properties.outputs.functionAppName.value" -o tsv)
echo "$FUNC"
```

Clone this sample (if you haven't already), install the Node dependencies from
`package.json`, and publish.

> ⚠️ **Do not skip `npm install`.** `func … publish` uploads the local project
> directory as-is and does not install dependencies on the server. Publishing
> without `node_modules/` leaves `onrampApimSync` failing at import — and
> because Event Grid probes the endpoint during subscription creation with a
> handshake POST, **Step 8 fails with a `webhookNotification` / webhook
> validation error** rather than at first invocation. Always run `npm install`
> in the same directory as `package.json` before `func … publish`.

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/apihub-plugins/azure/apim

az login       # if not already authenticated
npm install    # installs dependencies declared in package.json into node_modules/
func azure functionapp publish "$FUNC" --javascript
```

Wait for **"Deployment successful"** (~1–2 minutes). The function
`onrampApimSync` is now live.

[func-tools]: https://learn.microsoft.com/azure/azure-functions/functions-run-local
[az-cli]: https://learn.microsoft.com/cli/azure/install-azure-cli

### Step 8: Create the Event Grid subscription

**8.1** Enable the APIM instance's **system-assigned managed identity** — API
Management uses this identity to authenticate to Event Grid when publishing
control-plane events, and Event Subscription creation fails without it. This is
a Microsoft-documented prerequisite ([reference][apim-eg]).

Either from the Portal — open the APIM service `<AZURE_APIM_SERVICE>` → left nav
**Security → Managed identities** → **System assigned** tab → toggle **Status =
On** → **Save** — or from Cloud Shell:

```bash
az apim update \
  --name <AZURE_APIM_SERVICE> \
  --resource-group <AZURE_RESOURCE_GROUP> \
  --set identity.type="SystemAssigned"
```

Wait ~30 seconds for the identity to provision.

**8.2** Create the Event Grid subscription. Azure Portal → APIM service
`<AZURE_APIM_SERVICE>` → left nav → **Events → + Event Subscription**.

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
:                       : the `func-apihub-onramp-<hash>`       :
:                       : Function App (from Step 6.4 output    :
:                       : `functionAppName`) → function         :
:                       : `onrampApimSync`                      :

Click **Create**. Wait ~30 seconds for provisioning.

[apim-eg]: https://learn.microsoft.com/en-us/azure/api-management/how-to-event-grid

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

-   WIF principal binding missing on the SA (revisit Step 6.5 with the
    `<AZURE_MI_OBJECT_ID>` from Step 6.4).
-   Federated credential missing on the App Registration (revisit Step 6.6).
-   IAM Credentials API not enabled (`gcloud services enable
    iamcredentials.googleapis.com --project=<GCP_PROJECT_ID>`).
-   Service account missing `roles/apihub.pluginAdmin` on the API hub project
    (revisit Step 4).
-   **VPC Service Controls violation (`HTTP 403`, `type: VPC_SERVICE_CONTROLS`,
    `reason: SECURITY_POLICY_VIOLATED`).** The API hub project sits in a service
    perimeter that does not yet permit the Function. See
    [VPC Service Controls](#vpc-service-controls) for the three ingress rules
    the push path needs.

## VPC Service Controls

If the API hub project is inside a VPC Service Controls perimeter, the
pull-based sync (Step 3) works without changes, but the real-time push path
(Steps 4–9) is blocked. The Function makes three sequential Google API calls,
each with a different caller — the perimeter must permit all three:

Service                         | Caller identity
------------------------------- | ----------------------------------------
`sts.googleapis.com`            | None (WIF exchange runs before auth)
`iamcredentials.googleapis.com` | Federated WIF principal
`apihub.googleapis.com`         | Impersonated `apihub-azure-onramp-sa` SA

The managed-identity token call that precedes them is served by the Azure
platform (`IDENTITY_ENDPOINT`), so it never crosses the perimeter.

### Step V1: Add ingress rules to the perimeter

Add three ingress rules to the perimeter that protects `<GCP_PROJECT_ID>`.

In the
[VPC Service Controls console](https://console.cloud.google.com/security/service-perimeter),
edit the perimeter and add each rule under **Ingress policy → Add rule**:

Rule | Identity                                                          | Service
---- | ----------------------------------------------------------------- | -------
1    | **Identity type: Any identity**                                   | `sts.googleapis.com`
2    | `principal://…/subject/<AZURE_MI_OBJECT_ID>` (full string below)  | `iamcredentials.googleapis.com`
3    | `apihub-azure-onramp-sa@<GCP_PROJECT_ID>.iam.gserviceaccount.com` | `apihub.googleapis.com`

For every rule, set **Source: All sources** and **Project: Selected projects →
`<GCP_PROJECT_ID>`**. The full Rule 2 identity string is:

```
principal://iam.googleapis.com/projects/<GCP_PROJECT_NUMBER>/locations/global/workloadIdentityPools/apihub-azure-onramp-pool/subject/<AZURE_MI_OBJECT_ID>
```

`<AZURE_MI_OBJECT_ID>` is the same value bound as `subject` in Step 5.3; read it
from the Bicep output in Step 6.4. Note the prefix is `principal://` (a single
workload identity), not `principalSet://`.

If the console rejects the Rule 2 identity string, apply all three rules with
gcloud instead — save the following under `status.ingressPolicies` in the
perimeter YAML and run `gcloud access-context-manager perimeters replace-all`:

```yaml
- ingressFrom:
    identityType: ANY_IDENTITY
    sources: [{accessLevel: '*'}]
  ingressTo:
    operations:
    - serviceName: sts.googleapis.com
      methodSelectors: [{method: '*'}]
    resources: [projects/<GCP_PROJECT_NUMBER>]
- ingressFrom:
    identities:
    - principal://iam.googleapis.com/projects/<GCP_PROJECT_NUMBER>/locations/global/workloadIdentityPools/apihub-azure-onramp-pool/subject/<AZURE_MI_OBJECT_ID>
    sources: [{accessLevel: '*'}]
  ingressTo:
    operations:
    - serviceName: iamcredentials.googleapis.com
      methodSelectors: [{method: '*'}]
    resources: [projects/<GCP_PROJECT_NUMBER>]
- ingressFrom:
    identities:
    - serviceAccount:apihub-azure-onramp-sa@<GCP_PROJECT_ID>.iam.gserviceaccount.com
    sources: [{accessLevel: '*'}]
  ingressTo:
    operations:
    - serviceName: apihub.googleapis.com
      methodSelectors: [{method: '*'}]
    resources: [projects/<GCP_PROJECT_NUMBER>]
```

Rule 1 uses **Any identity** because the STS token exchange has no GCP identity
to match against yet. IAM still enforces the real access control — only tokens
whose issuer and audience match the provider configured in Step 5.2 are
exchanged, and the result can only impersonate the SA bound in Step 5.3.

Perimeter changes take 1–5 minutes to propagate.

### Step V2: If your organization disallows `ANY_IDENTITY`

Some organizations forbid `ANY_IDENTITY` in ingress rules. Replace Rule 1 with
an [access level](https://console.cloud.google.com/access-context-manager) that
matches the Function's outbound IP addresses, and set that access level as the
`sources` entry instead of `'*'`.

Read the addresses from **Function App → Networking → Outbound IP addresses**
(or `az functionapp show --query possibleOutboundIpAddresses`). On a Consumption
(Y1) plan this set is shared and can change when the app moves scale units, so
prefer an Elastic Premium plan or a NAT gateway with a static egress IP if you
depend on it.

### Step V3: Confirm a denial is really VPC Service Controls

A perimeter denial surfaces as `HTTP 403` with `type: VPC_SERVICE_CONTROLS` and
`reason: SECURITY_POLICY_VIOLATED` in the Function's **Monitor** output, not as
a permission error. Copy the `vpcServiceControlsUniqueIdentifier` from the
exception and paste it into Cloud Console → **Security → VPC Service Controls →
Troubleshoot** to identify which perimeter and which service blocked the call.

Which service appears in the violation tells you which rule is missing: a denial
on `sts.googleapis.com` means Rule 1, `iamcredentials.googleapis.com` means Rule
2, and `apihub.googleapis.com` means Rule 3.

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
