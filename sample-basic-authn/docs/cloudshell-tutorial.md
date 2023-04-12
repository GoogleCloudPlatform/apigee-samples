# Basic Authentication

---
This sample allows you to authenticate an incoming request with a Basic Authentication header using a `client_id` and a `client_secret` as the encoded credential pair. 

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'sample-basic-authn' drirectory in the Cloud shell.

```sh
cd sample-basic-authn
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="sample-basic-authn/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `APIGEE_HOST` the hostname used to expose an Apigee environment group to the Internet

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Deploy Apigee components

Next, let's create and deploy the Apigee resources.

```sh
./deploy-basic-authn.sh
```

This script creates an API Proxy, an API product, a sample App developer, and an App.

The script output will provide values for `CLIENT_ID`, `ClIENT_SECRET` and an encoded Basic Authentication header that you'll be able to use in the next step.

## Testing the sample

 Set the Basic Authentication as a value of the `BASIC_AUTH` environment variable and send a cURL request as shown below:

```
BASIC_AUTH=REPLACE_WITH_IDP_ACCESS_TOKEN
curl -v https://$APIGEE_HOST/v1/samples/basic-auth -H "Authorization: $BASIC_AUTH"
```

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully configured Basic Authentication in an API Proxy!

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to delete the artifacts from this example from your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-basic-authn.sh
```
