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

## Deploy Apigee Proxy and KVM

Now, let's deploy the sample proxy with the script below. It will also create the proxy-scoped KVM - but empty.

```bash
./setup.sh
```

Check the output of the script. Notice it won't populate the KVM file for you. In the local folder, you can see a sample KVM content file (ending with \_sample). Feel free to copy
the contents of it if you are just testing. Consider adding your own paths for your real use-case.

After the local KVM file is updated, import it to Apigee with the command from the output script. You can also use the list command to verify the actual contents of the KVM.

As you migrate new paths, the idea is to update this file, adding a new entry for the migrated path, and re-importing the KVM.

This can be done with re-deploying the proxy! This is the power of Apigee KVMs.

## Test the functionality

The setup script also shows you a few curl examples with invalid, monolith and microservice-migrated paths. Few free to adapt and experiment, use the Apigee Debug for details and more!

## Conclusion & Cleanup

If you want to clean up the artifacts from this example in your project, first source your env.sh script, and then run:

```bash
./cleanup.sh
```
