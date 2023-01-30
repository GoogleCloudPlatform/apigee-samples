# Integrated developer portal

---
This sample lets you create an integrated developer portal for your API product

Let's get started!

---

## Setup environment

Navigate to the 'integrated-developer-portal' drirectory in the Cloud shell.

```sh
cd integrated-developer-portal
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="integrated-developer-portal/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```
---

## Deploy Apigee components

Next, let's deploy the Apigee resources necessary to create an integrated developer portal

```sh
./deploy-integrated-developer-portal.sh
```

This script creates an API Proxy, API product, a sample App developer, and App. The script also tests that the deployment and configuration has been sucessfull. It does not, however, create the developer portal. We will create and test that manually. 


## Manually call the API

The script that deploys the Apigee API proxies prints the proxy and app information you will need to run the commands below.

```sh
curl -X GET 'http://$APIGEE_HOST/v1/sample/integrated-developer-portal?apikey=$APP_CLIENT_ID'
```
> _Note: Under normal circumstances, avoid providing secrets on the command itself using `-u`_

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully created an api secured proxy and all the resources needed to access it. Now we need to create the integrated developer portal.

Navigate back to the Github README.md doc where we first started. Find the "Create Integrated Developer Portal" section and pick up from there.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

After you create your integrated developer portal you can clean up the artefacts from this sample in your Apigee Organization. First source your `env.sh` script, and then run

```bash
./clean-up-oauth-client-credentials.sh
```

After this, you need to manually delete the Apigee portal. Navigate to Publish > Portals, find you portal in the portal table, hover over it, and select the trash can icon to permanently delete your integrated developer portal.