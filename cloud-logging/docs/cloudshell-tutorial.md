# Apigee Cloud Logging Tutorial

---
This sample let you configure an Apigee Proxy that will write custom log entries to GCP Cloud Logging

Let's get started!

---

## Setup environment

Navigate to the 'cloud-logging' drirectory in the Cloud shell.

```sh
cd cloud-logging
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="cloud-logging/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

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

Next, let's create the service account, make sure it has the proper role for writing into Cloud Logging and then deploy the actual Apigee proxy.

```sh
./deploy-cloud-logging.sh
```

The proxy itself is configured to write logs to a log named _projects/$PROJECT/logs/apigee_

### Test the APIs

Generate a few sample requests to the deployed API Proxy.

```
curl  https://$APIGEE_HOST/samples/cloud-logging
```
> _If you want, consider also checking the call in the [Debug](https://cloud.google.com/apigee/docs/api-platform/debug/trace) view_

After issuing some calls, let's confirm the configured variables / values set on the Message Logging policy were successfully writen to Cloud Logging with 

```
gcloud logging read "logName=projects/$PROJECT/logs/apigee"
```

Cloud Logging is quite powerful. Few free to navigate to its UI in the GCP Console (_Logging_ Product Page in the console) and explore additional features such as filters, custom searchs, custom alerts and much more.

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully made an Apigee Proxy send custom logging messages to Google Cloud Logging!

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artefacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-cloud-logging.sh
```