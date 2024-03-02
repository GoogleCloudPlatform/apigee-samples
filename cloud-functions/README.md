# Connect to Cloud Function from an Apigee Proxy

This sample demonstrates how to connect to a Cloud Function (gen2) from an Apigee API Proxy.

[Cloud Functions](https://cloud.google.com/functions) is Google Cloud's
Functions-as-a-Service offering.

This sample will use a Cloud Function that responds to HTTP calls.  In this
sample, the Cloud Function runs with the identity of a specific service account,
and the Apigee proxy that invokes it, runs with the identity of a different
service account.

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)

2. Access to import and deploy proxies to Apigee, and deploy Cloud Functions

3. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance

## Using this Sample

There are two ways to use this sample:

1. Click a link to follow the guided tutorial that relies on GCP Cloud Shell.

2. Follow the steps Manually in  your own terminal.

The two following sections provide the guidance for these respective options.
You only need one!

## Option 1: Cloud Shell Guided Tutorial

Click the link to follow a tutorial that runs right within GCP
Cloud Shell. Follow the instructions as shown on the right hand side of your
browser window.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=cloud-functions/docs/cloudshell-tutorial.md)

## Option 2: Manual steps in your own Terminal

You will need to open a Linux-like terminal in order to follow these steps. The
Debian variant in [Google Cloud Shell](https://shell.cloud.google.com/) works;
MacOS works; sorry, Powershell does not. This sample demonstrates how to connect
to a Cloud Function from an Apigee Proxy.

Make sure the following tools are available in your terminal's PATH
    *[gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    *curl
    * jq
    * npm

Cloud Shell has all of these pre-configured. If you use your own machine, you
will need to install these yourself.

After you've insured the pre-requisites are in order, you can get started. Follow the
steps in [Manual-Steps.md](./Manual-Steps.sh).
