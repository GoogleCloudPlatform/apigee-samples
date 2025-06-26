# API Hub Portal Publishing Sample
This sample shows how unmanaged APIs can be registered in API Hub, and then on-ramped as a managed API in Apigee, as well as documented in an [Apigee developer portal](https://cloud.google.com/apigee/docs/api-platform/publish/portal/build-integrated-portal).

## Prerequisites
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) will be used for automating GCP tasks, see the docs site for installation instructions.
- [apigeecli](https://github.com/apigee/apigeecli) will be used for Apigee automation, see the docs site for installation instructions.
- [Apigee](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro) and [Apigee API Hub](https://cloud.google.com/apigee/docs/apihub/what-is-api-hub) provisioned in a GCP region.
- GCP roles needed:
  - roles/apigee.apiAdminV2 - needed to deploy an Apigee proxy.
  - roles/apigee.portalAdmin - needed to manage the Apigee integrated developer portal.
  - roles/apihub.editor - needed to manage API Hub data
- An [Apigee Integrated Developer Portal](https://cloud.google.com/apigee/docs/api-platform/publish/portal/build-integrated-portal) needs to be provisioned and visible at in the [Apigee Portals Console](https://console.cloud.google.com/apigee/portals)

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions in Cloud Shell. Alternatively, follow the instructions below.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=apihub-portal-publish/docs/cloudshell-tutorial.md)

## Setup instructions

### Step 1: Set your GCP project environment variables

To begin, set your environment variables to be used in the `env.sh` file.

* `PROJECT_ID` the project where your Apigee organization is located.
* `REGION` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV.
* `APIGEE_ENV` the Apigee environment where the demo resources should be created.
* `APIGEE_HOST` the Apigee host of the environment / environment group to reach the proxy
* `APIGEE_PORTAL_URL` the Apigee integrated portal URL (visible [here](https://console.cloud.google.com/apigee/portals)), must be the `*.apigee.io` URL, not a custom domain.

Now source the environment variables file.

```sh
source env.sh
```

### Step 2: Register an unmanaged API in API Hub

To begin, you will register the **unmanaged** API at [https://mocktarget.apigee.net/help](https://mocktarget.apigee.net/help) to API Hub. This makes the API visible, and is the first step to adding management and official documentation for the API.

```sh
./deploy-unmanaged-api.sh
```

Now open the [API Hub Console](https://console.cloud.google.com/apigee/api-hub/apis) to see the registered API, version, deployment and spec. Notice how the deployment is tagged as **Unmanaged** since it is not secured or running on an API platform. The API version is also labled as **Test** in the Lifecycle attribute, and the deployment documentation link opens the static [HTML site](https://mocktarget.apigee.net/help).

### Step 3: Create a managed Apigee proxy for unmanaged API

This step will deploy an Apigee proxy to make the API managed, and add it as an additional deployment of type **Apigee** and environment **Production.** It will also update and publish the API docs to the Apigee integrated portal.

```sh
./deploy-managed-api.sh
```

Open the [API Hub Console](https://console.cloud.google.com/apigee/api-hub/apis) to see the updated API, version, and the new managed deployment and spec, this time in **Apigee**. Notice how the new Apigee deployment links to the Apigee portal with testable documentation and user registration, and connected to an [Apigee product](https://cloud.google.com/apigee/docs/api-platform/publish/what-api-product) for access & user management.

### Step 4: Clean up resources

Clean up all of the resources.

```sh
./cleanup-solution.sh
```

Congrats, you registered an unmanaged API to API Hub, created a managed proxy and developer portal documentation for the API thereby making it managed, and then updated API Hub with the new deployment and documentation information.