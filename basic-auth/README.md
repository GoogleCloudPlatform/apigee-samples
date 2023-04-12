# Basic Authentication


This sample allows you to authenticate an incoming request with a Basic Authentication header using a `client_id` and a `client_secret` as the encoded credential pair. 

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Access to deploy proxies, create products, apps and developers in Apigee
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
   * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
   * unzip
   * curl
   * jq
   * npm

# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/ra2085/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=basic-auth/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-usecase-mashup repo, and switch the basic-auth directory

```bash
git clone https://github.com/ra2085/apigee-usecase-mashup.git
cd apigee-usecase-mashup/basic-auth
```

2. Edit the `env.sh` and configure the ENV vars. If you don't set variables that are marked as `Optional`, then the deploy script will also provision a mock OIDC authorization server that will allow you to issue JWT access tokens to test this sample


* `PROJECT` the project where your Apigee organization is located
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `APIGEE_HOST` the hostname used to expose an Apigee environment group to the Internet

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee artifacts and environment configuration

```bash
./deploy-sample-basic-authn.sh
```

The script output will provide values for `CLIENT_ID`, `ClIENT_SECRET` and an encoded Basic Authentication header that you'll be able to use in the next step.

## Testing the sample

 Set the Basic Authentication as a value of the `BASIC_AUTH` environment variable and send a cURL request as shown below:

```
BASIC_AUTH=
curl -v https://$APIGEE_HOST/v1/samples/basic-auth -H "Authorization: $BASIC_AUTH"
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-basic-authn.sh
```