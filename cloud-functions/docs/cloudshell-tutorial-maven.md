# Sample to use Cloud Functions from Apigee Proxy using Maven and Cloud Build

---
This sample demonstrates how to use Cloud functions from Apigee Proxy using Cloud Build

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'cloud-functions' directory in the Cloud shell.

```sh
cd cloud-functions
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="cloud-functions/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Cloud Functions Sample

First, let enabled the Cloud ResourceManager API, Cloud Build API and Cloud Functions API. 

```sh
gcloud services enable cloudresourcemanager.googleapis.com cloudbuild.googleapis.com cloudfunctions.googleapis.com
```

Once the API is enabled, lets assign the Apigee Org Admin role, Cloud Functions Admin and Service Account Admin and User Role to the Cloud Build service account

```sh
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/apigee.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/cloudfunctions.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/iam.serviceAccountAdmin"
```

Now lets trigger the Cloud Build using the command

```sh
gcloud builds submit --config cloudbuild.yaml . \
    --substitutions="_SERVICE=$CLOUD_FUNCTION_SERVICE","_REGION=$CLOUD_FUNCTION_REGION","_APIGEE_TEST_ENV=$APIGEE_ENV"
```

This will trigger the Cloud Build and execute the steps in the <walkthrough-editor-open-file filePath="cloud-functions/cloudbuild.yaml">cloudbuild.yaml</walkthrough-editor-open-file> file. At the end of the Cloud Build trigger, a proxy must be deployed to Apigee called `apigee-samples-cloud-functions`


### Test the APIs

You can test the API call to make sure the deployment was successful

```sh
curl https://$APIGEE_HOST/v1/samples/apigee-samples-cloud-functions
```

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed a Cloud Functions and invoked from Apigee.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-cloud-functions.sh
```
