# Monolith to Microservice Migration based on Paths

This sample shows how Apigee can be used as a façade to facilitate the migration from a monolith to a microservice architecture.

Let's get started!

## Setup instructions

1. Navigate to the 'monolith-to-microservices-based-on-paths' directory in the Cloud Shell.

   ```bash
   cd monolith-to-microservices-based-on-paths
   ```

2. Ensure you have an active GCP account selected in the Cloud shell

   ```bash
   gcloud auth login
   ```

3. Edit the `env.sh` and configure the ENV vars specific to your installation. Click <walkthrough-editor-open-file filePath="monolith-to-microservices-based-on-paths/env.sh">here</walkthrough-editor-open-file> to open the file in the editor.

   - `PROJECT_ID` the project where your Apigee organization is located.
   - `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV without https://
   - `APIGEE_ENV` the Apigee environment where the demo resources should be created.
   - `MICROSERVICE_PATH` is the destination URL (preceed with http:// or https://) of the modern, new destination. If just testing, you can use https://httpbin.org/get
   - `LEGACY_PATH` is the destination URL (preceed with http:// or https://) of the monolith, legacy destination. If just testing, you can use https://httpbin.org/get

   Now source the `env.sh` file

   ```bash
   source ./env.sh
   ```

## Deploy Apigee Proxy

Now, let's deploy the sample proxy with the script below. It will also create the proxy-scoped KVM - but empty.

```bash
./setup.sh
```

Check the output of the script. Notice it won't populate the KVM file for you. In the local folder, you can see a sample KVM content file (ending with \_sample). Feel free to copy
the contents of it if you are just testing. Consider adding your own paths for your real use-case.

After you are done, please execute the following command to import the file into the KVM in Apigee:

```bash
TOKEN=$(gcloud auth print-access-token)
export PATH=$PATH:$HOME/.apigeecli/bin

apigeecli kvms entries import -p custom-routing -m routing-rules -f ./proxy__custom-routing__routing-rules__kvmfile__0.json -o $PROJECT_ID -t \$TOKEN > /dev/null 2>&1

```

Now, you can go check the state of the KVM in Apigee with:

```bash

apigeecli kvms entries list -p custom-routing -m routing-rules -o $PROJECT_ID -t \$TOKEN "
```

As you migrate new paths, the idea is to update this file, adding a new entry for the migrated path, and re-importing the KVM.

This can be done without re-deploying the proxy! This is the power of Apigee KVMs.

## Test the functionality

Now, let's test with a few curl calls - invalid paths, migrated paths and legacy paths. Adapt the paths for your own where needed.

```bash
curl -i https://${APIGEE_HOST}/v1/samples/custom-routing/invalid-path
curl -i https://${APIGEE_HOST}/v1/samples/custom-routing/migrated
curl -i https://${APIGEE_HOST}/v1/samples/custom-routing/still/legacy
```

## Conclusion & Cleanup

If you want to clean up the artifacts from this example in your project, first source your env.sh script, and then run:

```bash
./cleanup.sh
```
