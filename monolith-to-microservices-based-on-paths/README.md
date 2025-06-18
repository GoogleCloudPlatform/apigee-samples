# Monolith to Microservice Migration based on Paths

This sample shows how Apigee can be used as a facade to facilitate the migration from a monolith to a microservice architecture.

## About the migration scenario

This sample shows a common pattern where currently a large monolith exposes multiple routes - such as /accounts , /banks, /users, /products... and many others. Given it is a monolith, it is common that the API it exposes is also a "combo" API that mixes multiple domains, different and potentially unrelated resources, and so.

A common strategy for modernizing services is to use the [strangling fig pattern](https://martinfowler.com/bliki/StranglerFigApplication.html) where we gradually "de-hydrate" the monolith into smaller microservices (running, let's say, in GKE or Cloud Run) over time. In this sample scenario, this modernization will be done by paths - that is, the customer will migrate one path at a time. That is - if the first path being migrated is "/first", they'll first develop and test a microservice for serving the resources for this path and once it is done, the traffic should flow to the newly create service. All other paths, which are still not migrated, should route to the monolith.

Overtime, more microservices will be created for each of the paths - and this should be fully transparent for the apps that are clients to the "original" API - and the traffic flow should get dynamically routed to the appropriate microservice.

Eventually, the monolith will be fully decommissioned.

## Challenges in this scenario

In general, we want to reduce the impact of the migration for any of the dependant systems. We don't want client apps to have to change their destination URLs or credentials for the API they consume whenever a new microservice is created/migrated.

Also notice that there might be complexities in the actual paths being migrated - they can either be explicit full paths (such /accounts/users) or they can have URI path parameters (such /accounts/{userId}/balance/{date}). Our solution should consider that as well.

From the perspective of the development team that is actually migrating the service, being able to rollback the routing quickly is important in case of any issues.

The facade strategy implement with Apigee in this sample aims to achieve exactly that.

## Implementation in Apigee

This implementation will basically leverage a proxy (named custom-routing) that implements the facade strategy. It also depends on a local, apiproxy-scoped KVM (named routing-rules) where our routing rules will be defined.

This implementation considers that the number of paths can be quite large - that is, the customer can be migrating 100's of paths. While creating individual flows for each of them is feasible, it becomes quite challenging to manage them all overtime. This implementation takes a more programatic approach to defining the routing rules based on the KVM then.

First of all, the KVM will have an entry called "allPaths" that basically is a long comma separated list of all the paths that exist (either in the monolith or already modernized). Paths with custom URI params are defined as /accounts/\*/balance/\* - that is, any "\*" represents a single URI path (that can be anything).

If the provided path in the call is not in the list of allowed paths, the proxy will return a 404.

If it is on the list, then we'll search for another entry in the same KVM - but now, using the corresponding path representation as a key (for instance, /accounts/\*). For all the paths we already migrated to a microservice, we will create an entry with the key (/accounts/\*) and a value of "microservice" - that basically represents this path has been migrated. In this sample, there's only one "microservice" target, but notice this can be easily expanded to multiple "new" destinations.

For mapping a given URI Path (proxy.pathsuffix) to the "\*" style described, we use some JS logic - both for defining if the provided path is on the list of allowed paths and finally for fetching the actual key for the KVM.

And basically, using Apigee Routing Rules, we'll decide which Target Server to route to - either the current (monolith) or the new one. Again, this could be easily expanded for multiple modernized target microservices.

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance or use [exposing-to-internet](../exposing-to-internet/README.md) sample in this repository.
3. Have access to deploy proxies in Apigee
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
   - [gcloud SDK](https://cloud.google.com/sdk/docs/install)
   - curl

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions in Cloud Shell. Alternatively, follow the instructions below.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=monolith-to-microservices-based-on-paths/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch to the monolith-to-microservices-based-on-paths directory

   ```bash
   git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
   cd apigee-samples/monolith-to-microservices-based-on-paths
   ```

2. Ensure you have an active GCP account selected in the Cloud shell

   ```bash
   gcloud auth login
   ```

3. Edit the `env.sh` and configure the ENV vars specific to your installation.

   - `PROJECT_ID` the project where your Apigee organization is located.
   - `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV without https://
   - `APIGEE_ENV` the Apigee environment where the demo resources should be created.
   - `MICROSERVICE_PATH` is the destination URL (preceded with http:// or https://) of the modern, new destination. If just testing, you can use <https://httpbin.org/get>
   - `LEGACY_PATH` is the destination URL (preceded with http:// or https://) of the monolith, legacy destination. If just testing, you can use <https://httpbin.org/get>

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

apigeecli kvms entries import -p custom-routing -m routing-rules -f ./proxy__custom-routing__routing-rules__kvmfile__0.json -o $PROJECT_ID -t $TOKEN > /dev/null 2>&1

```

Now, you can go check the state of the KVM in Apigee with:

```bash

apigeecli kvms entries list -p custom-routing -m routing-rules -o $PROJECT_ID -t $TOKEN
```

As you migrate new paths, the idea is to update this file, adding a new entry for the migrated path, and re-importing the KVM.

This can be done without re-deploying the proxy! This is the power of Apigee KVMs.

## Test the functionality

Now, let's test with a few curl calls - invalid paths, migrated paths and legacy paths. Adapt the paths for your own where needed.

```bash
curl -i https://${APIGEE_HOST}/v1/samples/custom-routing/invalid-path
```

```bash
curl -i https://${APIGEE_HOST}/v1/samples/custom-routing/migrated
```

```bash
curl -i https://${APIGEE_HOST}/v1/samples/custom-routing/still/legacy
```

## Conclusion & Cleanup

If you want to clean up the artifacts from this example in your project, first source your env.sh script, and then run:

```bash
./cleanup.sh
```
