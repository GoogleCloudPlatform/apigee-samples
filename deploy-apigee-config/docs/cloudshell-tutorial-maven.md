# Sample to automate Apigee configurations using Maven and Cloud Build

---
This sample demonstrates how to use the [Apigee Maven config plugin](https://github.com/apigee/apigee-config-maven-plugin) to push environment configurations like Targetservers, KeyValueMaps and Organization configurations like API Products, Developers and Developer Apps to Apigee using [Cloud Build](https://cloud.google.com/build/docs/overview)

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'deploy-apigee-config' directory in the Cloud shell.

```sh
cd deploy-apigee-config
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="deploy-apigee-config/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee configurations

Next, let's deploy the sample configurations to Apigee using the Maven plugin and Cloud Build

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

This will trigger the Cloud Build and execute the steps in the <walkthrough-editor-open-file filePath="deploy-apigee-config/cloudbuild.yaml">cloudbuild.yaml</walkthrough-editor-open-file> file. At the end of the Cloud Build trigger, the configurations should be created in your Apigee org.


### Verification

To verify if the configurations were created, login to the [Apigee console](https://apigee.google.com).
- Navigate to "Admin" --> "Environments" --> "Target Servers", you should see a target server `SampleTarget` created.
- Similarly navigate to "Admin" --> "Environments" --> "Key Value Maps", you should see a Key Value Map `SampleKVM` created
- Navigate to "Publish" --> "API Products", you should find the `sample-product` product created.
- Navigate to "Publish" --> "Developers", you should find the `Sample Developer` developer created.
- Navigate to "Publish" --> "Apps", you should find the `sampleapp` app created.

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed Apigee configurations using the Maven plugin and Cloud Build. For more info on the other options available in the plugin, check the plugin [documentation](https://github.com/apigee/apigee-config-maven-plugin)

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-deploy-apigee-config.sh
```