# API Hub Portal Publishing Sample

This sample shows how unmanaged APIs can be registered to API Hub, turned into managed APIs in Apigee, and then published to an Apigee portal.

Let's get started!

---

## Prepare project dependencies

### 1. Ensure that prerequisite tools are installed, and that you have needed permissions.

- [gcloud CLI](https://cloud.google.com/sdk/docs/install) will be used for automating GCP tasks, see the docs site for installation instructions.
- [apigeecli](https://github.com/apigee/apigeecli) will be used for Apigee automation, see the docs site for installation instructions.
- [Apigee](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro) and [Apigee API Hub](https://cloud.google.com/apigee/docs/apihub/what-is-api-hub) provisioned in a GCP region. The original API Hub test data that come from provisioning should be available.
- GCP roles needed:
  - roles/apigee.apiAdminV2 - needed to deploy an Apigee proxy.
  - roles/apigee.portalAdmin - needed to manage the Apigee integrated developer portal.
  - roles/apihub.editor - needed to manage API Hub data
- An [Apigee Integrated Developer Portal](https://cloud.google.com/apigee/docs/api-platform/publish/portal/build-integrated-portal) needs to be provisioned and visible at in the [Apigee Portals Console](https://console.cloud.google.com/apigee/portals)

### 2. Ensure you have an active GCP account selected in the Cloud Shell.

```sh
gcloud auth login
```

## Set environment variables

First update the `env.sh` file with your environment variables. Click <walkthrough-editor-open-file filePath="apihub-portal-publish/env.sh">here</walkthrough-editor-open-file> to open the file in the editor.

* `PROJECT_ID` the project where your Apigee organization is located.
* `REGION` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV.
* `APIGEE_ENV` the Apigee environment where the demo resources should be created.
* `APIGEE_HOST` the Apigee host of the environment / environment group to reach the proxy
* `APIGEE_PORTAL_URL` the Apigee integrated portal URL (visible under Location [here](https://console.cloud.google.com/apigee/portals)), must be the `*.apigee.io` URL, not a custom domain.

After saving, switch to the `apihub-portal-publish` directory and source the env file.

```sh
cd apihub-portal-publish
source env.sh
```

## Register unmanaged API in API Hub

To begin, you will register the **unmanaged** API at [https://mocktarget.apigee.net/help](https://mocktarget.apigee.net/help) to API Hub. This makes the API visible, and is the first step to adding management and official documentation for the API.

```sh
./deploy-unmanaged-api.sh
```

<walkthrough-web-preview-icon></walkthrough-web-preview-icon> Now open the [API Hub Console](https://console.cloud.google.com/apigee/api-hub/apis) to see the registered API, version, deployment and spec. Notice how the deployment is tagged as **Unmanaged** since it is not secured or running on an API platform. The API version is also labled as **Test** in the Lifecycle attribute, and the deployment documentation link opens the static [HTML site](https://mocktarget.apigee.net/help).

## Add management to the API and register in an Apigee portal

This step will deploy an Apigee proxy to make the API managed, and add it as an additional deployment of type **Apigee** and environment **Production.** It will also update and publish the API docs to the Apigee integrated portal.

```sh
./deploy-managed-api.sh
```

<walkthrough-web-preview-icon></walkthrough-web-preview-icon> Open the [API Hub Console](https://console.cloud.google.com/apigee/api-hub/apis) to see the updated API, version, and the new managed deployment and spec, this time in **Apigee**. Notice how the new Apigee deployment links to the Apigee portal with testable documentation and user registration, and connected to an [Apigee product](https://cloud.google.com/apigee/docs/api-platform/publish/what-api-product) for access & user management.

## Congratulations

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

You're all set!

**Don't forget to clean up after yourself**. Execute the following commands to undeploy and delete all sample resources.

```sh
./cleanup-solution.sh
```
