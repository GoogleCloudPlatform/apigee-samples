# Sample to use Cloud Run Service from Apigee Proxy using Maven and Cloud Build

---
This sample demonstrates how to use Cloud Run Services from Apigee Proxy using Cloud Build

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'deploy-apigee-proxy' directory in the Cloud shell.

```sh
cd cloud-run
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="cloud-run/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Cloud Run Sample

First, let enabled the Cloud Build API, Cloud Run API and Container Registry API

```sh
gcloud services enable cloudbuild.googleapis.com run.googleapis.com containerregistry.googleapis.com
```

Once the API is enabled, lets assign the Apigee Org Admin role, Cloud Run Admin and Service Account Admin and User Role to the Cloud Build service account

```sh
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/apigee.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/run.admin"

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
    --substitutions="_SERVICE=$CLOUD_RUN_SERVICE","_REGION=$CLOUD_RUN_REGION","_APIGEE_TEST_ENV=$APIGEE_ENV"
```

This will trigger the Cloud Build and execute the steps in the <walkthrough-editor-open-file filePath="cloud-run/cloudbuild.yaml">cloudbuild.yaml</walkthrough-editor-open-file> file. At the end of the Cloud Build trigger, a proxy must be deployed to Apigee called `cloud-run-sample`


### Test the APIs

You can test the API call to make sure the deployment was successful

```sh
curl https://$APIGEE_HOST/v1/samples/cloud-run-sample
```

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed an Apigee proxy using the Maven plugin and Cloud Build

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-cloud-run.sh
```
