# Publish OpenAPI Spec to Apigee Integrated portal using Apigee Maven plugin and Cloud Build

---
This sample demonstrates how to use the [Apigee Maven config plugin](https://github.com/apigee/apigee-config-maven-plugin) to publish configurations like API Docs and API Categories to Apigee Integrated Portal using [Cloud Build](https://cloud.google.com/build/docs/overview)

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'publish-to-apigee-portal' directory in the Cloud shell.

```sh
cd publish-to-apigee-portal
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="publish-to-apigee-portal/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee configurations

Next, let's deploy the Apigee artifacts (proxy, target server, API Product) to Apigee, API Category and Spec to the Integrated portal using the Maven plugin and Cloud Build

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
    --substitutions="_APIGEE_HOST=$APIGEE_HOST,_APIGEE_TEST_ENV=$APIGEE_ENV,_APIGEE_PORTAL_SITE_ID=$APIGEE_PORTAL_SITE_ID"
```

This will trigger the Cloud Build and execute the steps in the <walkthrough-editor-open-file filePath="publish-to-apigee-portal/cloudbuild.yaml">cloudbuild.yaml</walkthrough-editor-open-file> file. At the end of the Cloud Build trigger, the configurations should be created in your Apigee org.

### Verification

To verify if the configurations were created, open your Integrated portal in a browser

* Click the "API" from the menu header, you should see `MockTarget` API created.
* Click `MockTarget` to see the different paths of the API
* Click the `/echo` path from the left menu and under the `Try this API` section, click the "EXECUTE" button to see the response from Apigee
* You can enable DEBUG in Apigee and make the calls from the portal to see the transaction in DEBUG

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed Apigee configurations using the Maven plugin and Cloud Build. For more info on the other options available in the plugin, check the plugin [documentation](https://github.com/apigee/apigee-config-maven-plugin)

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./cleanup.sh
```
