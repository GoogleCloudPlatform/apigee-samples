<!--
 Copyright 2026 Google LLC

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

# Sync API metadata from AWS API Gateway to Google Cloud Apigee API hub

This sample covers the one-time plugin instance setup that seeds API hub with
all existing APIs and supports on-demand re-syncs, plus an optional AWS Lambda
deployment that pushes individual API Gateway control-plane events to API hub
via EventBridge for continuous synchronization. Authentication to Google Cloud
uses Workload Identity Federation — no long-lived credentials are stored in AWS.

## Prerequisites

1.  **AWS:** an account with API Gateway APIs to synchronize and permission to
    create IAM users and deploy CloudFormation stacks (which create IAM roles,
    Lambda functions, and EventBridge rules).
2.  **Google Cloud:** an API hub-provisioned project. See
    [Provision API hub](https://cloud.google.com/apigee/docs/apihub/provision).
3.  **IAM on GCP side:** `roles/apihub.admin`,
    `roles/iam.workloadIdentityPoolAdmin`, `roles/iam.serviceAccountAdmin`,
    `roles/secretmanager.admin`, and `roles/resourcemanager.projectIamAdmin` (or
    `roles/owner`).

## Values to gather before starting

Substitute these throughout the setup steps.

Placeholder               | Where to find it
------------------------- | ----------------
`<GCP_PROJECT_ID>`        | Your target API hub project
`<GCP_PROJECT_NUMBER>`    | Shown below the project ID in the GCP Console picker
`<GCP_LOCATION>`          | Region where API hub instance is hosted in
`<PLUGIN_INSTANCE_ID>`    | Auto-generated in [Step 3](#step-3-create-the-api-hub-plugin-instance); visible on the instance details page
`<AWS_ACCOUNT_ID>`        | Top-right dropdown in the AWS Console
`<AWS_REGION>`            | Top-right region picker in the AWS Console
`<AWS_ACCESS_KEY_ID>`     | Created in [Step 1](#step-1-create-an-aws-iam-user-for-api-hub) (AWS IAM user's access key)
`<AWS_SECRET_ACCESS_KEY>` | Created in [Step 1](#step-1-create-an-aws-iam-user-for-api-hub) (shown once at access-key creation)
`<SECRET_NAME>`           | You choose this in [Step 2](#step-2-store-the-aws-secret-key-in-google-secret-manager) (e.g., `apihub-aws-secret-access-key`)

## Setup Instructions

### Step 1: Create an AWS IAM user for API hub

API hub uses OAuth2-style client credentials to read API metadata from AWS.
Create a dedicated IAM user with **read-only** access to API Gateway, and
generate a long-lived access key for it.

**1.1** In AWS Console → **IAM → Users → Create user**:

| Field                          | Value                                    |
| ------------------------------ | ---------------------------------------- |
| User name                      | `apihub-aws-reader`                      |
| Provide user access to the AWS | **Unchecked** (programmatic access only) |
: Management Console             :                                          :

Click **Next**.

**1.2** On the **Set permissions** page, choose **Attach policies directly** →
**Create policy**, then paste the following JSON in the **JSON** tab:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ApiHubDiscoveryReadOnly",
            "Effect": "Allow",
            "Action": [
                "apigateway:GET"
            ],
            "Resource": "*"
        }
    ]
}
```

Name the policy (e.g., `ApiHubDiscoveryReadOnly`), save it, and attach it to the
user. Click **Next → Create user**.

**1.3** Open the newly created `apihub-aws-reader` user → **Security
credentials** tab → **Access keys → Create access key**.

-   Use case: **Application running outside AWS** (or **Other**).
-   Click **Next → Create access key**.

**1.4** Copy both values immediately (the secret will not be shown again):

-   `<AWS_ACCESS_KEY_ID>` (e.g., `AKIA...`)
-   `<AWS_SECRET_ACCESS_KEY>` (long random string)

You will store these in GCP Secret Manager in the next step.

### Step 2: Store the AWS secret key in Google Secret Manager

The API hub plugin instance reads `<AWS_SECRET_ACCESS_KEY>` from a Secret
Manager secret. The access key ID is not sensitive and goes directly on the
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

printf '%s' '<AWS_SECRET_ACCESS_KEY>' | \
  gcloud secrets versions add <SECRET_NAME> \
  --data-file=- \
  --project=<GCP_PROJECT_ID>
```

Use a descriptive `<SECRET_NAME>` such as `apihub-aws-secret-access-key`.

> ⚠️ `printf '%s'` (no trailing newline) is important. `echo` appends `\n` and
> produces an invalid signature at request time.

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

The Lambda publishes API metadata into a plugin instance of the built-in
`system-aws-apigateway` plugin. Create one instance per (AWS account, AWS
region) pair that you plan to sync.

**3.1** In your browser, open API hub in the Cloud console:

```
https://console.cloud.google.com/apigee/apihub/settings/plugins?project=<GCP_PROJECT_ID>
```

**3.2** In the **Google Cloud plugins** tab, click **AWS API Gateway**
(`system-aws-apigateway`) → **Create instance**.

**3.3** Fill in the form.

**Details:**

Field        | Value
------------ | ------------------------
Display name | Any human-readable label

**Configuration:**

Field              | Value
------------------ | ---------------------------------
**aws-account-id** | `<AWS_ACCOUNT_ID>`
**aws-region**     | `<AWS_REGION>` (e.g. `us-east-1`)

**Authentication:**

Field                                        | Value
-------------------------------------------- | -----
**Auth type**                                | **OAuth 2.0 Client Credentials** (required)
**Client ID**                                | `<AWS_ACCESS_KEY_ID>` from Step 1
**Client secret** (Secret Manager reference) | `projects/<GCP_PROJECT_ID>/secrets/<SECRET_NAME>/versions/latest` from Step 2.4

**Sync frequency:**

| Field        | Value                                                       |
| ------------ | ----------------------------------------------------------- |
| **Schedule** | Runs automatically every **6 hours** by default. Adjust the |
:              : frequency if you want more or less frequent syncs.          :

**3.4** Click **Create instance** and wait for the status to become **Active**
(~30 seconds). Note the auto-generated **instance ID** shown on the details page
— this is `<PLUGIN_INSTANCE_ID>` for Step 7.

> **Initial sync happens automatically.** Once the plugin instance is Active,
> API hub kicks off a one-time backfill that discovers every existing API
> Gateway API in `<AWS_ACCOUNT_ID>` / `<AWS_REGION>` and registers it in API
> hub. This may take a few minutes depending on the number of APIs. Verify the
> results in the API hub Console under **APIs**.

**Keeping API hub in sync going forward.** After the initial backfill, you have
three ways to pick up APIs that are created or updated later:

1.  **Scheduled auto-sync (enabled by default).** The `sync-metadata` action
    runs every **6 hours** on its own — no action required. Adjust the frequency
    in the plugin instance's Actions section if you want more or less frequent
    syncs.
2.  **On-demand pull from API hub.** In the API hub Console, open the plugin
    instance and click **Run** to trigger a sync immediately. Useful right after
    a bulk deployment when you don't want to wait for the next scheduled run.
3.  **Real-time push from AWS (this sample).** Deploy the Lambda + EventBridge
    stack described in Steps 4–9 below. AWS then pushes individual API Gateway
    control-plane events to API hub within ~30–60 seconds of each change.

The three options are complementary — you can enable real-time push later
without redoing the plugin instance setup.

### Step 4: Create a GCP service account for the Lambda

At
`https://console.cloud.google.com/iam-admin/serviceaccounts?project=<GCP_PROJECT_ID>`
click **+ Create Service Account**.

Field                | Value
-------------------- | ------------------------------------------------------
Service account name | `aws-realtime-lambda`
Role                 | **Cloud API hub Plugins Admin** (`apihub.pluginAdmin`)

The full SA email will be
`aws-realtime-lambda@<GCP_PROJECT_ID>.iam.gserviceaccount.com`.

### Step 5: Configure Workload Identity Federation

At
`https://console.cloud.google.com/iam-admin/workload-identity-pools?project=<GCP_PROJECT_ID>`
click **Create Pool**.

**5.1 Create pool:**

Field   | Value
------- | -------------------
Name    | `aws-realtime-pool`
Enabled | Checked

**5.2 Add provider:**

Field          | Value
-------------- | -----------------------
Provider       | **AWS**
Provider name  | `aws-realtime-provider`
AWS Account ID | `<AWS_ACCOUNT_ID>`

Leave the "Configure provider attributes" step at its defaults.

**5.3 Grant access** — pick **"Grant access using service account
impersonation"** (not federated identities), select the `aws-realtime-lambda`
SA, and add a principal with:

Attribute name | Attribute value
-------------- | ---------------
`aws_role`     | `arn:aws:sts::<AWS_ACCOUNT_ID>:assumed-role/aws-onramp-realtime-<AWS_REGION>-role`

**5.4 Build the WIF audience string** (needed in Step 7):

```
//iam.googleapis.com/projects/<GCP_PROJECT_NUMBER>/locations/global/workloadIdentityPools/aws-realtime-pool/providers/aws-realtime-provider
```

### Step 6: Enable CloudTrail management events

In AWS Console → **CloudTrail → Trails** for `<AWS_REGION>`, confirm you have a
trail with **Status: Logging** that captures **Management events → Read and
Write**. If not, create one (any name, any S3 bucket).

### Step 7: Deploy the CloudFormation stack

In AWS Console → **CloudFormation → Create stack → With new resources** in
`<AWS_REGION>`.

-   **Template:** upload `cloudformation.yaml` from this directory.
-   **Stack name:** `aws-onramp-realtime-poc`
-   **Parameters:**

    Parameter        | Value
    ---------------- | -----
    GcpProject       | `<GCP_PROJECT_ID>`
    GcpLocation      | `<GCP_LOCATION>`
    PluginInstanceId | `<PLUGIN_INSTANCE_ID>`
    WifAudience      | The string from Step 5.4
    WifSaEmail       | `aws-realtime-lambda@<GCP_PROJECT_ID>.iam.gserviceaccount.com`

    Leave `ApihubHost`, `PluginId`, and `ActionId` at their defaults.

-   Check **"I acknowledge that AWS CloudFormation might create IAM resources
    with custom names"** → **Submit**.

Wait for status **CREATE_COMPLETE** (~2 minutes).

### Step 8: Upload the Lambda code

The template ships a placeholder handler so the function exists before the real
code is uploaded.

1.  In AWS Console → **Lambda → Functions**, open the function whose name starts
    with `aws-onramp-realtime-`.
2.  On the **Code** tab, ensure the file is named `index.mjs`. If it is
    `index.js`, right-click → **Rename** → `index.mjs`. (Node.js treats `.js` as
    CommonJS and rejects the ES module `import` statements otherwise.)
3.  Open `index.mjs`, select all, delete, and paste the contents of `index.mjs`
    from this directory.
4.  Click **Deploy** and wait for "Successfully updated the function."

### Step 9: Verify

Deploy any existing REST API in **API Gateway Console** to a new stage named
`realtime-test-1`. Within 30–60 seconds:

-   A new log stream should appear in **CloudWatch → Log groups →
    /aws/lambda/aws-onramp-realtime...** showing the WIF token exchange and the
    API hub POST.
-   The API should show up in API hub at
    `https://console.cloud.google.com/apigee/apihub?project=<GCP_PROJECT_ID>`
    with `realtime-test-1` as a deployment entry.

## Files Included

-   `cloudformation.yaml`: AWS infrastructure template (Lambda + IAM role
    +   EventBridge rule).
-   `index.mjs`: The AWS Lambda handler (Node.js 20+, zero npm dependencies).

## Disclaimer

This is a sample integration and may require modifications to fit your specific
security and operational requirements.
