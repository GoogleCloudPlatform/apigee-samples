# Drupal developer portal

---
This sample lets you create an Drupal developer portal for your API product

Let's get started!

---

## Setup environment

1. Navigate to the 'drupal-developer-portal' drirectory in the Cloud Shell.

```sh
cd drupal-developer-portal
```

2. Edit the `env.sh` and configure the ENV vars. Click <walkthrough-editor-open-file filePath="drupal-developer-portal/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```sh
source ./env.sh
```

3. Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```
---

## Deploy Apigee components

Next, let's deploy some Apigee resources necessary to create an Drupal developer portal

```sh
./deploy-drupal-developer-portal.sh
```

**NOTE: This script creates an API Proxy and API product. It does not, however, create the developer portal. We will create and test that manually**

---
## Test Drupal Developer Portal

Now that we have a developer portal, let's walk through its workflow.

---
## Conclusion & Cleanup

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully created an Drupal developer portal for your Apigee API.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

To clean up the artifacts created:

First, you need to manually delete your Drupal developer portal
After that, source your `env.sh` script and run the following to delete your product and proxy:

```bash
./clean-up-drupal-developer-portal.sh
```