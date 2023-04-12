# Basic Authentication

This sample allows you to authenticate an incoming request using a Basic Authentication header using a `USER_ID` and a `USER_PASSWORD` as the encoded credential pair. Basic Authentication based on [RFC 7617](https://www.ietf.org/rfc/rfc2617.txt) is often used to secure system to system interactions. This scheme allows a client to authenticate itself by sending a base 64 encoded user id and password pair on each HTTP request, making it insecure if not used in combination of transport layer encryption (credentials are sent in clear text). Strong anti-spoofing controls should be put in place to prevent conterfeit servers from stealing credentials.

## Prerequisites
1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Access to deploy proxies, create products, apps and developers in Apigee
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
   * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
   * curl
   * jq

# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=basic-auth/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the apigee-samples repo, and switch the basic-auth directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/basic-auth
```

2. Edit the `env.sh` and configure the ENV vars.


* `PROJECT` the project where your Apigee organization is located
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `APIGEE_HOST` the hostname used to expose an Apigee environment group to the Internet
* `USER_ID` the user id that you'd like to use to create the basic authentication header
* `USER_PASSWORD` the user password that you'd like to use to create the basic authentication header

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee artifacts and environment configuration

```bash
./deploy-sample-basic-authn.sh
```

The script output will provide values for `USER_ID`, `USER_PASSWORD` and an encoded Basic Authentication header that you'll be able to use in the next step.

## Testing the sample

 Set the Basic Authentication as a value of the `BASIC_AUTH` environment variable and send a cURL request as shown below (the deployment script already provides a cURL request):

```
curl -v https://$APIGEE_HOST/v1/samples/basic-auth -H "Authorization: $BASIC_AUTH"
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-basic-authn.sh
```