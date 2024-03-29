# Sample to use Cloud Run Service from an Apigee Proxy

---
This sample demonstrates how to use Cloud Run Services from Apigee Proxy.
We'll use Cloud Build to build and deploy the Cloud Run Service, and the Apigee Proxy.

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'cloud-run' directory in the Cloud shell.

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

First, lets enable the IAM API, Cloud Build API, Cloud Run API and Container Registry API

```sh
gcloud services enable iam.googleapis.com cloudbuild.googleapis.com run.googleapis.com containerregistry.googleapis.com
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

This will trigger the Cloud Build and execute the steps in the
<walkthrough-editor-open-file
filePath="cloud-run/cloudbuild.yaml">cloudbuild.yaml</walkthrough-editor-open-file>
file. At the end of the Cloud Build trigger, a Cloud Run service will
be deployed and available, and an API
proxy called `cloud-run-sample` will be deployed to Apigee.

### Test the APIs

You can test the API call to make sure the deployment was successful

```sh
curl -i https://$APIGEE_HOST/v1/samples/cloud-run-sample
```

This sends a request to Apigee, which then connects to the Cloud Run service.

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully demonstrated an Apigee Proxy that connects
to Cloud Run Services. You used Cloud Build to build and deploy both the Cloud
Run Service, _and_ to deploy the Apigee API Proxy.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee
Organization, first source your `env.sh` script, and then run

```bash
./clean-up-cloud-run.sh
```
