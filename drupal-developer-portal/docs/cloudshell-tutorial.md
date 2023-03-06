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
## Configure Drupal Developer Portal

Now we will configure our Drupal Devoper Portal and expose our Apigee API product through it

### Finish Portal Configuration and Sync with Apigee

Here we will enter our portal for the first time and sync it with our Apigee organization

1. Navigate to the [Deployment Manager Deployments](https://console.cloud.google.com/dm/deployments) page in the GCP. Find your Drupal deployment and click into it
2. Once your portal has finished initializing, access and sign into your app using the https link and the basic auth credentials
3. Verify details after sign in and complete Drupal installation
4. Configure the endpoint to reflect Apigee X and paste in your Apigee Org ID
5. Configure your site with the information and admin account of your chosing. Be sure that you have no typos when defining this information
6. Choose to install the Demo Content

### Add Apigee Product to the Drupal API Catalog

Now we will actually add Hello World Product to our Drupal API Catalog. This section takes within the Drupal portal and assumes that you are signed into your admin account. If you don't see the admin bar at the top of your site then sign in.

1. From the Drupal portal, navigate to Content > API Catalog
2. Click the "Add content" button
3. Configure as shown below
- Name: Sample Drupal Developer Portal API
- Description: A portal for an API key protected proxy
- Audience: Anonymous users (anyone can view)
- Image: Image of your choice (optional)
- API Product: sample-integrated-developer-portal-product
- Specification Source Type: File
- OpenAPI specification: Use the [drupal-developer-portal.yaml](drupal-developer-portal.yaml) OpenAPI document from this repo:
    - If you ran the deployment script from Cloud Shell:
        - Navigate back to Cloud Shell
        - Open integrated-developer-portal.yaml & downlod it to your local computer. No need to update file content as it was already updated when running the deployment script.
    - Otherwise, do the following:
        - Download [integrated-developer-portal.yaml](integrated-developer-portal.yaml) to your local computer
        - Open the file and replace "\[APIGEE_HOST\]" with your own Apigee host/domain.
    - Upload your updated integrated-developer-portal.yaml file as API documentation
4. Fill in the info accordingly --> Name: Hello World, Description: A simple hello world API, Image: your choice, Specification Source Type: File, OpenAPI specification: upload your hello-world-spec-open.yaml, API Product: Hello World Product, Published: leave checked
5. Scroll up and click save

### Create API App in Drupal

Now we will create ourselves an App within Drupal. This will create us an API key which we will need to call the API

1. From the Drupal homepage, navigate to Apps. The button is in the navbar next to the My account and Log out buttons
2. Click the Add app button. Name your new app "Sample Drupal Portal App", leave Callback URL blank as well as the Description, finally make sure that the sample-drupal-portal-product is selected.
3. Within your new Drupal App, copy the Consumer Key. You'll use this for authenticating into your API
4. Optional, view the corresponding App in Apigee by going to Apigee > Publish > Apps

## Test Drupal Developer Portal

Finally, we will test out our Drupal portal by making secured requests to our API through it

1. Navigate to your Drupal portal Homepage. Scroll down to Featured APIs and select "View All APIs". Find your Hello World API and view it's documentation
2. From within the API select the "Authorize" button and save your API Key within
3. Select the / GET call from under API REFERENCE. Under Try this API click EXECUTE
4. Voila! You have a working API secured and documented within your Marketplace Drupal Portal!

---
## Conclusion & Cleanup

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully created an Drupal developer portal for your Apigee API.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

To clean up the artifacts created:

First, you need to delete the resources we manually created

1. From the Apigee console, navigate to Publish > Developers
2. Find the account you created in your developer portal, hover over it, and select the trash can icon to delete. This will also delete all Apigee Apps associated with your developer
3. From the GCP Deployment Manager Deployments page select your sample-drupal-developer-portal deployment and click delete at the top

After that, source your `env.sh` script and run the following to delete your product and proxy:

```bash
./clean-up-drupal-developer-portal.sh
```