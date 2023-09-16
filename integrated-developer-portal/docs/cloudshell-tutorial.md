# Integrated developer portal

---
This sample lets you create an integrated developer portal for your API product

Let's get started!

---

## Setup environment

1. Navigate to the 'integrated-developer-portal' drirectory in the Cloud Shell.

```sh
cd integrated-developer-portal
```

2. Edit the `env.sh` and configure the ENV vars. Click <walkthrough-editor-open-file filePath="integrated-developer-portal/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

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

Next, let's deploy some Apigee resources necessary to create an integrated developer portal

```sh
./deploy-integrated-developer-portal.sh
```

**NOTE: This script creates an API Proxy and API product. It does not, however, create the developer portal. We will create and test that manually**

---

## Create Integrated Developer Portal

You've successfully deployed a secured Apigee proxy. Now we need to provision the integrated developer portal:

1. Access the portals page from the [Apigee homepage](https://apigee.google.com). Make sure you are in the correct organization before navigating to Publish > Portals
2. Click the +Portal button
3. For name you can use "Sample Integrated Developer Portal". You can leave Description blank.

We also need to add our API product to the portal:

1. Access your new Sample Integrated Developer Portal
2. Enter the API catalog tab, if not already selected
3. Click + to add a new API product to the catalog
4. Select the sample-integrated-developer-portal-product product and click next
5. Configure as shown below

* Published: Select published (checked)
* Display title: Leave default name, sample-integrated-developer-portal-product
* Display description: A portal for an API key protected proxy
* Require developers to specify a callback URL: Keep deselected (unchecked)
* Audience: Anonymous users (anyone can view)
* API product image: Image of your choice (optional)
* API documentation: Use the <walkthrough-editor-open-file filePath="integrated-developer-portal/integrated-developer-portal.yaml">integrated-developer-portal.yaml</walkthrough-editor-open-file> OpenAPI document from this repo:
  * If you ran the deployment script from Cloud Shell:
    * Navigate back to Cloud Shell
    * Open integrated-developer-portal.yaml & downlod it to your local computer. No need to update file content as it was already updated when running the deployment script.
  * Otherwise, do the following:
    * Download <walkthrough-editor-open-file filePath="integrated-developer-portal/integrated-developer-portal.yaml">integrated-developer-portal.yaml</walkthrough-editor-open-file> to your local computer
    * Open the file and replace "\[APIGEE_HOST\]" with your own Apigee host/domain.
  * Upload your updated integrated-developer-portal.yaml file as API documentation

6. Scroll up and click save

---

## Test Integrated Developer Portal

Now that we have a developer portal, let's walk through its workflow. First we'll create our developer account and sign in, then we'll make an Apigee app complete with a client id and secret, and finally we'll use the client id to authorize our requests and test our API. To do so, follow the steps below:

1. Navigate to your newly created portal. Portals > Sample Integrated Developer Portal
2. Enter the portal by clicking the Live Portal button at the top right, or with the following URL: https://\[APIGEE-ORG\]-sampleintegrateddeveloperportal.apigee.io
3. Click the Sign In button and create an account. You need to enter a valid email as the portal necessitate an email confirmation. Note: this creates an Apigee developer account
4. Navigate back to your portal's homepage (https://\[APIGEE-ORG\]-sampleintegrateddeveloperportal.apigee.io) and make sure that you're signed in
5. Open the dropdown menu by clicking on your account and select Apps
6. Select +NEW APP and update the following fields. Note: this creates an Apigee App for your developer

* App Name: Sample App
* APIs: Enable sample-integrated-developer-portal-product

7. Click the SAVE button
8. Click into APIs from the top navbar
9. Click into your sample-integrated-developer-portal-product
10. Select AUTHORIZE and select your app from the dropdown. This authorizes all of your portal requests with your App's API key
11. Select the / GET request Path
12. Under Try this API, click the EXECUTE button
13. You should receive a 200 OK response from Apigee. The body of the response is a copy of the request data you sent to Apigee

---

## Conclusion & Cleanup

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully created an integrated developer portal for your Apigee API.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

To clean up the artifacts created:

First, you need to manually delete some Apigee resources

1. Navigate to Publish > Developers
2. Find the account you created in your developer portal, hover over it, and select the trash can icon to delete. This will also delete all Apigee Apps associated with your developer
3. Navigate to Publish > Portals
4. Find your Sample Integrated Developer Portal, hover over it, and select the trash can icon to delete

After that, source your `env.sh` script and run the following to delete your product and proxy:

```bash
./clean-up-integrated-developer-portal.sh
```
