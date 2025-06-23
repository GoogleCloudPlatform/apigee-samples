# Apigee mTLS Southbound Tutorial

This sample creates a small VM with a southbound mTLS service, as well as an Apigee proxy with a truststore and certificate to connect to the VM as a target service.

Let's get started!

---

## Prepare project dependencies

### 1. Ensure that prerequisite tools are installed, and that you have needed permissions.

- [gcloud CLI](https://cloud.google.com/sdk/docs/install) will be used for automating GCP tasks, see the docs site for installation instructions.
- [apigeecli](https://github.com/apigee/apigeecli) will be used for Apigee automation, see the docs site for installation instructions.
- GCP roles needed:
  - roles/compute.instanceAdmin - needed to create a VM.
  - roles/compute.networkAdmin - needed to create a firewall rule to allow the VM to get scp commands on port 22.
  - roles/apigee.apiAdminV2 - needed to deploy an Apigee proxy.
  - roles/apigee.environmentAdmin - needed to manage the Keystore and Target configuration.

### 2. Ensure you have an active GCP account selected in the Cloud Shell.

```sh
gcloud auth login
```

## Set environment variables

First update the `env.sh` file with your environment variables. Click <walkthrough-editor-open-file filePath="mtls-southbound/env.sh">here</walkthrough-editor-open-file> to open the file in the editor.

* `PROJECT_ID` the project where your Apigee organization is located.
* `REGION` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV.
* `APIGEE_ENV` the Apigee environment where the demo resources should be created.
* `APIGEE_HOST` the Apigee host of the environment / environment group to reach the proxy
* `ZONE` the GCP zone where a test southbound mtls VM should be deployed.
* `VM_NAME` the name of the test VM to be created.

After saving, switch to the `mlts-southbound` directory and source the env file.

```sh
cd mtls-southbound
source env.sh
```

## Deploy sample

Run this script to deploy the sample VM with [nginx](https://nginx.org/) running to handle the mTLS backend requests, and an Apigee proxy with Truststore to access the mTLS service.

```sh
./deploy-sample.sh
```

## Test Apigee API proxy to reach mTLS service

Now start a debug session for the proxy `mtls-southbound-v1` and do a test call to the service. It should successfully respond "access to mTLS-protected resource".

```sh
curl https://$APIGEE_HOST/v1/samples/mtls-southbound
```

## Congratulations

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

You're all set!

**Don't forget to clean up after yourself**. Execute the following commands to undeploy and delete all sample resources.

```sh
./clean-up-sample.sh
```
