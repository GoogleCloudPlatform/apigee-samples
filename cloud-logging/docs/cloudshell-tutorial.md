# Apigee Cloud Logging Tutorial

---
This sample let you configure an Apigee Proxy that will write custom log entries to GCP Cloud Logging

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'cloud-logging' directory in the Cloud shell.

```sh
cd cloud-logging
```

Edit the provided sample `env.sh` file, and set the environment variables there.

   * `PROJECT` the project where your Apigee organization is located
   * `APIGEE_ENV` the Apigee environment where the demo resources should be created
   * `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV

Click <walkthrough-editor-open-file filePath="cloud-logging/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Check your role

Check that your account has the necessary roles for this sample.

```bash
./check-role.sh
```

This script will show your identity and the roles associated to your identity.

If you have editor or owner roles, you will be able to proceed. If you do not have these roles, but
you have these roles:
 * `roles/iam.serviceAccountCreator`
 * `roles/resourcemanager.projectIamAdmin`
 * `roles/apigee.apiAdminV2`

...then you can use this sample, but you need to insure some other person has enabled the Cloud
Logging API on your project. We will check that the Logging API is enabled in the next step.

---

## Verify that the Logging API is enabled

Owners or Editors on a Google Cloud Project must enable individual services, for
them to be available.  Let's check that the Logging API is enabled.


```bash
./check-required-services.sh
```

* If this indicates that the logging API is already enabled on the project, you can proceed.

* If the logging API is not enabled, but you have editor or owner role (as shown in the previous
  step), then the script you run in the next step will enable the logging API.

* If the logging API is not enabled, and you do not have editor or owner role, then you need to
  stop, and find someone who can enable that API on your GCP project, before proceeding here.

---

## Deploy Apigee components

Next, let's create the service account, make sure it has the proper role for writing into Cloud Logging and then deploy the actual Apigee proxy.

```sh
./deploy-cloud-logging.sh
```

The proxy itself is configured to write logs to a log named _projects/$PROJECT/logs/apigee_

## Test the APIs

Generate a few sample requests to the deployed API Proxy.

```sh
curl  https://$APIGEE_HOST/v1/samples/cloud-logging
```

> _If you want, consider also checking the call in the [Debug](https://cloud.google.com/apigee/docs/api-platform/debug/trace) view_

After issuing some calls, let's confirm the configured variables / values set on the Message Logging policy were successfully written to Cloud Logging with

```sh
gcloud logging read "logName=projects/$PROJECT/logs/apigee"
```

Cloud Logging is quite powerful. Few free to navigate to its UI in the GCP
Console (_Logging_ Product Page in the console) and explore additional features
such as filters, custom searches, custom alerts and much more.

If you are so inclined, you can modify the apiproxy, introducing new policies,
or modifying the existing MessageLogging policy. Re-deploy the updated version,
and then re-run your tests, and re-examine the logs.

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully made an Apigee Proxy send custom logging messages to Google Cloud Logging!

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-cloud-logging.sh
```
