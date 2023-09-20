# Sample to automate Apigee proxy deployments using Maven and Cloud Build

---
This sample demonstrates how to use the [Apigee Maven deploy plugin](https://github.com/apigee/apigee-deploy-maven-plugin) to deploy a proxy to Apigee using Cloud Build

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'deploy-apigee-proxy' directory in the Cloud shell.

```sh
cd deploy-apigee-proxy
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="deploy-apigee-proxy/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee proxy

Next, let's deploy the sample proxy to Apigee using the Maven plugin and Cloud Build

First, let's enable the Cloud Build API

```sh
gcloud services enable cloudbuild.googleapis.com
```

Once the API is enabled, lets assign the Apigee Org Admin role to the Cloud Build service account

```sh
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/apigee.admin"
```

Now lets trigger the Cloud Build using the command

```sh
gcloud builds submit --config cloudbuild.yaml . \
      --substitutions="_APIGEE_TEST_ENV=$APIGEE_ENV"
```

This will trigger the Cloud Build and execute the steps in the <walkthrough-editor-open-file filePath="deploy-apigee-proxy/cloudbuild.yaml">cloudbuild.yaml</walkthrough-editor-open-file> file. At the end of the Cloud Build trigger, a proxy must be deployed to Apigee called `sample-hello-cicd`

### Test the APIs

You can test the API call to make sure the deployment was successful

```sh
curl https://$APIGEE_HOST/v1/samples/hello-cicd
```

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed an Apigee proxy using the Maven plugin and Cloud Build

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-deploy-apigee-proxy.sh
```
