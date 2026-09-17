# Azure API Management to Google Cloud API Hub — Real-Time On-Ramp

This sample keeps Google Cloud API Hub **continuously in sync** with an Azure API Management (APIM) instance. Whenever an API is created, updated, or deleted in APIM, an Event Grid event triggers an Azure Function that pushes the change to API Hub in near real time.

It is the **event-driven counterpart** to the batch [`azure-apim`](../azure-apim) plugin (which syncs on a schedule via Application Integration). Pick this one when you need low-latency sync and prefer a **keyless** trust model.

## How it works

```text
APIM  (API created/updated/deleted)
   │  emits event
   ▼
Azure Event Grid ──► Azure Function (onrampApimSync)
                        │  authenticates with Workload Identity Federation
                        │  (no client secret / no stored key)
                        ▼
                 Google Cloud API Hub  (plugin instance updated)
```

- **Trigger:** Event Grid subscription on the APIM service for `Microsoft.ApiManagement.API{Created,Updated,Deleted}`.
- **Compute:** a small Azure Function App (Node.js) running `onrampApimSync`.
- **Auth to Google:** **Workload Identity Federation (WIF)** — the Function's Azure managed identity is federated to a GCP Workload Identity Pool, so **no long-lived secret is stored** (a key difference from the batch plugin, which uses a client secret).

## Where to run this

This plugin spans **two clouds**. `azure_setup.sh` needs `az`, `func`, and `bicep`; `gcp_setup.sh` needs `gcloud`. No single shell ships both toolchains by default, so pick **one** of the three ways below.

| Tool | Used by | Azure Cloud Shell | Google Cloud Shell | Local terminal |
| --- | --- | :---: | :---: | :---: |
| `az`, `func`, `bicep` | `azure_setup.sh` | native | install | install |
| `gcloud` | `gcp_setup.sh` | install | native + pre-authenticated | install |

### Option 1 — Azure Cloud Shell for everything (Recommended)

Run **both** scripts from Azure Cloud Shell. `az`/`func`/`bicep` are native; you install `gcloud` once and it persists. Attach a storage account to Azure Cloud Shell first so `$HOME` (the cloned repo and the gcloud install) persists, then:

```bash
curl https://sdk.cloud.google.com > /tmp/install_gcloud.sh
bash /tmp/install_gcloud.sh --disable-prompts --install-dir="$HOME"
source "$HOME/google-cloud-sdk/path.bash.inc"
gcloud auth login --no-launch-browser
gcloud config set project <GCP_PROJECT_ID>
```

In a later session, if `gcloud` isn't found, re-run the `source` line above.

### Option 2 — Azure Cloud Shell (Azure side) + Google Cloud Shell (GCP side)

No installs anywhere — each shell already has its own toolchain. Run `azure_setup.sh` in Azure Cloud Shell and `gcp_setup.sh` in Google Cloud Shell (`gcloud` is native and pre-authenticated there). Copy the generated `generated.env` into the plugin folder in Google Cloud Shell before running `gcp_setup.sh`.

### Option 3 — Fully local terminal

Install the whole toolchain (`az`, `func`, `bicep`, `node`, `gcloud`, `jq`, `bash`), then `az login` and `gcloud auth login`, and follow the Setup steps below.

## Prerequisites

1. **Azure**
    - An Azure Subscription with an **existing APIM instance**.
    - **Entra (app registration):** creating an App Registration works **by default** (the tenant setting *"Users can register applications"* is `Yes` out of the box). You only need to act if your tenant has **disabled** it: ask an admin to re-enable it, grant your account the **Application Developer** role, or have an admin create the app and set `APP_ID` in `env.sh`. `azure_setup.sh` pre-checks this and exits early with a clear message and the `APP_ID` fallback.
    - **Subscription/RG level:** `Owner` or `Contributor` on the resource group (to deploy resources), plus `Owner` or `User Access Administrator` to assign the APIM `Reader` role, and `Contributor` on the APIM (to enable its managed identity).
    - **Region note:** some subscriptions have an Azure Policy that restricts regions. This sample deploys its resources into the **same region as your APIM instance** to avoid `RequestDisallowedByAzure` errors.
2. **Google Cloud**
    - A project with **API Hub provisioned** ([guide](https://cloud.google.com/apigee/docs/apihub/provision)) and an existing **`system-azure-apim` plugin instance** — its id goes in `env.sh` as `INSTANCE_ID`.
    - `gcloud` authenticated to that project.
    - Roles for the user running `gcp_setup.sh`:
        - `roles/apihub.admin`
        - `roles/iam.workloadIdentityPoolAdmin` (to create the WIF pool/provider)
        - `roles/iam.serviceAccountAdmin` and `roles/resourcemanager.projectIamAdmin` (or `roles/owner`)
    - APIs enabled (the setup script does this for you): `apihub.googleapis.com`, `iamcredentials.googleapis.com`, `sts.googleapis.com`.
3. **Tools:** `az`, `func` (Azure Functions Core Tools), `bicep`, `gcloud`, `jq`, `node`, `bash`. How you obtain these depends on the option you pick in [Where to run this](#where-to-run-this).

## Setup Instructions

All the fiddly parts (App Registration, region selection, function runtime, enabling the APIM managed identity, and Event Grid ordering) are handled **inside the scripts** — you just run them in order.

**Navigation:** you `cd` into the plugin folder **once** (Step 1). Every command after that is run **from that folder**. `source env.sh` only affects the shell it runs in — if you open a new Cloud Shell tab, `cd` back and `source env.sh` again first.

### Step 1 — Prepare your environment and get the files

Set up your shell using **one** of the three options in [Where to run this](#where-to-run-this), then clone the repo and change into the plugin folder:

```bash
git clone https://github.com/<your-fork>/apigee-samples.git
cd apigee-samples/apihub-plugins/azure-apim-onramp-realtime
```

### Step 2 — Authenticate to both clouds

```bash
az account set --subscription <AZURE_SUBSCRIPTION_ID>
gcloud config set project <GCP_PROJECT_ID>
```

### Step 3 — Configure your values

Edit `env.sh` and fill in every `<PLACEHOLDER>` (Azure resource group + APIM name + subscription; GCP project + project number + API Hub location + plugin instance id + host):

```bash
code env.sh      # or: vi env.sh
```

### Step 4 — Load the values

```bash
source env.sh
```

### Step 5 — Configure Azure & deploy (run this BEFORE the GCP step)

Creates the App Registration, deploys the Bicep template (Function App + storage + plan + managed identity + the APIM `Reader` role, plus optional Application Insights), publishes the `onrampApimSync` function, enables the APIM system-assigned managed identity, and creates the Event Grid subscription:

```bash
./azure_setup.sh
```

When it finishes it **automatically writes the three values the GCP step needs** (`AZURE_TENANT_ID`, `AZURE_APP_ID`, `AZURE_MI_OBJECT_ID`) to a generated file `generated.env`. To collect function logs, set `export ENABLE_APP_INSIGHTS=true` in `env.sh` before running (Application Insights is off by default).

### Step 6 — Configure Google Cloud

Auto-loads `generated.env` from the previous step, then creates the service account (one per project) with `roles/apihub.editor`, plus the Workload Identity Pool + provider (issuer = tenant, audience = app id), binds the managed identity subject to the service account, enables APIs, and reuses your API Hub plugin instance:

```bash
./gcp_setup.sh
```

When it finishes, the on-ramp is live — no further action is needed. The scripts are idempotent: re-running reuses existing resources.

**Two-shell users:** copy the generated `generated.env` into the plugin folder in Google Cloud Shell before running `gcp_setup.sh`.

## Verify

1. In the Azure Portal, create or edit any API in your APIM instance.
2. Within a few seconds the change appears in your API Hub plugin instance.
3. To watch function execution, use the Azure Portal **Log stream** or Application Insights for the Function App (Application Insights is optional — enable it with `ENABLE_APP_INSIGHTS=true`; `az webapp log tail` is not supported on Linux Consumption Function Apps).

## Cleanup

To remove everything the sample created (or run `./cleanup.sh`):

- Delete the Event Grid subscription on the APIM service.
- Delete the Function App, App Service plan, storage account, user-assigned identity, and optional Application Insights created by the Bicep deployment.
- Delete the App Registration / Service Principal.
- Delete the Workload Identity Pool/provider and service account in Google Cloud.

## Files Included

- `README.md` — this file.
- `env.sh` — environment variables you edit before running the scripts.
- `gcp_setup.sh` — creates the service account (+ `apihub.editor`), the WIF pool/provider and impersonation binding, and enables the required Google Cloud APIs.
- `azure_setup.sh` — creates the App Registration, deploys the Bicep template, publishes the function, enables the APIM managed identity, and creates the Event Grid subscription.
- `cleanup.sh` — removes the resources the sample created.
- `main.bicep` — infrastructure: user-assigned identity, storage account, App Service plan, Function App, optional Application Insights, and the APIM `Reader` role assignment.
- `src/functions/onrampApimSync.js` — the Event Grid–triggered sync function.
- `host.json`, `package.json` — Azure Functions runtime configuration.
- `.gitignore` — excludes `generated.env`, `node_modules/`, and `local.settings.json` from commits.

`generated.env` is created at runtime by `azure_setup.sh` (the automatic Azure→GCP handoff) and is **not** committed.

## Disclaimer

This is a sample integration and may require modifications to fit your specific security and operational requirements.
