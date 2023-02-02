# Integrated developer portal

---
This sample lets you create an integrated developer portal for your API product

Let's get started!

---

## Setup environment

Navigate to the 'integrated-developer-portal' drirectory in the Cloud Shell.

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

This script creates an API Proxy and API product. It does not, however, create the developer portal. We will create and test that manually. 

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully created an API secured proxy and an associated API product. Now we need to create the integrated developer portal & test the API with it.

Navigate back to the Github README.md doc where we first started. Find the "Create Integrated Developer Portal" section and pick up from there.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

After you create your integrated developer portal you can clean up the artefacts from this sample in your Apigee Organization. First source your `env.sh` script, and then run

```bash
./clean-up-integrated-developer-portal.sh
```

After this, you need to manually delete manually created Apigee resources
1. Navigate to Publish > Developers
2. Find the account you created in your developer portal, hover over it, and select the trash can icon to delete
3. Navigate to Publish > Portals
4. Find your Sample Integrated Developer Portal, hover over it, and select the trash can icon to delete