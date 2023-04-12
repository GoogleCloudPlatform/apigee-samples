# Basic Authentication

---
This sample allows you to authenticate an incoming request using a Basic Authentication header using a `USER_ID` and a `USER_PASSWORD` as the encoded credential pair. Basic Authentication based on [RFC 7617](https://www.ietf.org/rfc/rfc2617.txt) is often used to secure system to system interactions. This scheme allows a client to authenticate itself by sending a base 64 encoded user id and password pair on each HTTP request, making it insecure if not used in combination of transport layer encryption (credentials are sent in clear text). Strong anti-spoofing controls should be put in place to prevent conterfeit servers from stealing credentials.

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'basic-auth' drirectory in the Cloud shell.

```sh
cd basic-auth
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="basic-auth/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `APIGEE_HOST` the hostname used to expose an Apigee environment group to the Internet
* `USER_ID` the user id that you'd like to use to create the basic authentication header
* `USER_PASSWORD` the user password that you'd like to use to create the basic authentication header

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

The script output will provide values for `USER_ID`, `USER_PASSWORD` and an encoded Basic Authentication header that you'll be able to use in the next step.

## Testing the sample

 Set the Basic Authentication as a value of the `BASIC_AUTH` environment variable and send a cURL request as shown below (the deployment script already provides a cURL request):

```
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
