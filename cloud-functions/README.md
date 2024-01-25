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

4. Make sure the following tools are available in your terminal's PATH
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm

   Cloud Shell has all of these pre-configured. If you use your own machine, you
   will need to install these yourself.

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

You will need to open a Linux-like terminal (MacOS works, sorry, Powershell does
not) in order to follow these steps.  This sample demonstrates how to connect to
a Cloud Function from an Apigee Proxy.

Let's get started!

## Verify that you are Logged in

Ensure you have an active GCP account, and you are logged in.

```sh
gcloud auth login
```

## Enable APIs

Ensure that the required APIs are enabled in your Google Cloud project. This includes the
APIs for Cloud Functions, IAM, Cloud Build, Cloud Run and Artifact Registry, as
well as Logging.

```sh
gcloud services enable \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  cloudfunctions.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  logging.googleapis.com
```


## Setup the environment

If your terminal is not in the `cloud-functions` directory, navigate there now:

```sh
cd cloud-functions
```

Using your favorite text editor, open the provided sample `env.sh` file, and
modify it to set the appropriate values for the environment variables listed
there.

In this sample, your Apigee proxy may run in a separate GCP project from your
Cloud Function. Or they may be in the same project. Set the appropriate
variables, depending on your preference.  You must have already created a
distinct project for Cloud Functions, if you want to use two distinct projects.

Save the file. Then, source the `env.sh` file in your terminal.

```sh
source ./env.sh
```

## Create service accounts

This sample uses two service accounts: one to provide the identity of the Cloud
Function, and another to provide the identity of the Apigee API proxy. These
service accounts may be in different GCP projects, if you are running your Cloud
Function in a different GCP Project than your Apigee. Or they may be in the same
project.  The projects are those you set in the prior step, in your modified
`env.sh` file.

Let's create the service accounts now.

First, the Service Account that will provide the identity for the Cloud Function:

```sh
CF_SA_NAME=cf-apigee-sample-sa-1
gcloud iam service-accounts create "$CF_SA_NAME" --project "$CLOUD_FUNCTIONS_PROJECT"
```

Capture the email address of that service account:

```sh
CF_SA_EMAIL="${CF_SA_NAME}@${CLOUD_FUNCTIONS_PROJECT}.iam.gserviceaccount.com"
```

Now, create the Service Account that will provide the identity of the Apigee proxy:

```sh
PROXY_SA_NAME=proxy-apigee-sample-sa-1
gcloud iam service-accounts create "$PROXY_SA_NAME" --project "$APIGEE_PROJECT"
```

Capture the email address of that service account also:

```sh
PROXY_SA_EMAIL="${PROXY_SA_NAME}@${APIGEE_PROJECT}.iam.gserviceaccount.com"
```


## Deploy the Cloud Function

In this sample, the logic for the cloud function is implemented in nodejs. This
app will be triggered by an HTTP request, and responds with a very simple
"Hello, World" response.  If you like, you can have a look at the app now, by
opening the [app.js](./app/app.js) file in your favorite text editor.

If you know nodejs, you could modify this app to do whatever you like. For now,
let's keep it as is.

Back to the terminal. Insure you are in the `app` subdirectory.

```sh
cd app
```

Now, deploy the simple app as a function.

```sh
gcloud functions deploy "$CLOUD_FUNCTION_NAME" \
  --gen2 \
  --project="$CLOUD_FUNCTIONS_PROJECT" \
  --runtime=nodejs18 \
  --region="$CLOUD_FUNCTIONS_REGION" \
  --source=. \
  --no-allow-unauthenticated \
  --service-account="${CF_SA_EMAIL}" \
  --entry-point=hello-sample \
  --trigger-http
```

Notice that we use `--no-allow-unauthenticated`, which means this function will
be accessible only from an authenticated and authorized client.

At the exit of that command, you will see a url, where the function is
accessible. Let's capture that url:

```sh
CF_URL=$(gcloud functions describe "$CLOUD_FUNCTION_NAME" --region="$CLOUD_FUNCTIONS_REGION" --format='value(url)')
```

And then we can invoke the function:

```sh
curl -i $CF_URL/hello-sample
```

The response to this should be a 403 code and an error message, because the
cloud function requires authentication, and the request we sent did not provide
an identity token. Let's correct that.

## Obtain an Identity Token

You will want to obtain an identity token, for the Service Account that
identifies the Apigee API Proxy. First, grant rights to yourself to do so:

```sh
WHOAMI=$(gcloud config list account --format "value(core.account)")
gcloud iam service-accounts add-iam-policy-binding "$PROXY_SA_EMAIL" \
    --project="$APIGEE_PROJECT" \
    --member="user:${WHOAMI}" \
    --role=roles/iam.serviceAccountUser
```

Now obtain the identity token identifying the Service Account. Notice that we
need to specify the `audience`, in the request for the token. The Cloud Function
will accept only Identity Tokens that correctly identify itself as the audience.

```sh
SA_ID_TOKEN=$(curl -s -X POST \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json" \
    -d '{"audience": "'${CF_URL}'", "includeEmail": "true"}' \
    "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${PROXY_SA_EMAIL}:generateIdToken" | jq -r '.token')
```

And now, pass that token in the invocation of the cloud function:

```sh
curl -i -H "Authorization: Bearer $SA_ID_TOKEN" "$CF_URL/hello-sample"
```

What happens?  You should again see a 403 response code, with a www-authenticate
header telling you the caller has insufficient scope. Why? The request included
an ID token with the correct audience. What's missing?

We need to grant permission to the Proxy Service Account, to invoke the Cloud
Function.

## Grant the Service Account permission to invoke the Function

This command says, "allow the given service account to invoke the specific Cloud Function":

```sh
gcloud functions add-invoker-policy-binding "$CLOUD_FUNCTION_NAME" \
    --member="serviceAccount:${PROXY_SA_EMAIL}" \
    --region="$CLOUD_FUNCTIONS_REGION" \
    --project="$CLOUD_FUNCTIONS_PROJECT"

```

You may need to wait a bit here, perhaps 30 seconds, for that change to take effect.
Then re-try the curl command:

```sh
curl -i -H "Authorization: Bearer $SA_ID_TOKEN" "$CF_URL/hello-sample"
```

...and you'll see that it works.

We have shown that the Cloud Function will allow an authenticated request,
bearing the ID token of a particular service account. Now let's use the API
Proxy to do that.


## The API Proxy

The configuration files for the Apigee API Proxy, which are stored in the
filesystem, already contain the appropriate configuration that tells Apigee to
use the identity of a service account for calls to the upstream.

If you open the file [target-1.xml](./bundle/apiproxy/targets/target-1.xml) in
your favorite text editor, you can see the relevant configuration.

The file should look something like this, but with the correct value for your
region and project.

```xml
  ...
  <HTTPTargetConnection>
    <Authentication>
      <GoogleIDToken>
        <Audience>https://us-west1-your-project-name.cloudfunctions.net/apigee-sample-hello</Audience>
      </GoogleIDToken>
    </Authentication>

    <SSLInfo>
      <Enabled>true</Enabled>
      <Enforce>true</Enforce>
    </SSLInfo>

    <!-- the proxy.pathsuffix will get appended -->
    <URL>https://us-west1-your-project-name.cloudfunctions.net/apigee-sample-hello</URL>
  </HTTPTargetConnection>
```

This tells Apigee to generate an ID token, for its service account, and pass it
to the upstream target. Which service account?  The one you specify when you
deploy the API Proxy. We'll do that next.

## Import and Deploy the proxy into Apigee

In the terminal, change back to the directory for this sample.
If your terminal window is in the `app` directory currently, this command will do it:

```sh
cd ..
```

Now, import and deploy the API Proxy.

```sh
./deploy-proxy-cloud-functions.sh
```

Deployment takes a few moments. The command will terminate when deployment is complete.


## Invoke the Apigee Proxy

After deployment of the API proxy succeeds, the proxy is ready to handle inbound
REST requests.

The URL for the Apigee proxy is a concatenation of:

- the scheme: `https://`
- the Apigee hostname
- the proxy basepath, `/v1/samples/cloud-function-http-trigger`
- the path suffix, `/hello-sample`

Let's send a GET request.

```sh
curl -i "https://$APIGEE_HOST/v1/samples/cloud-function-http-trigger/hello-sample"
```

You can see the output from the Cloud Function.

## Commentary on Credentials

Your curl command sent no Authorization header. During handling of the inbound
request, the Apigee proxy created the appropriate Authorization header,
containing a token that identifies the appropriate Service Account. The proxy
then passed that Authorization header in the request that it sends to the target
cloud function.

Typically, an Apigee proxy will perform "security mediation" - it accepts one
kind of credential on input, and uses a different credential for requests sent
to the target. The input credential might be an OAuth2 access token issued by
Apigee, while the credential used for the target could be an ID token, if the
target is a cloud function.

In this particular sample, the Apigee proxy did not require any credential on
the inbound request. But that is only because this is a simplified sample. You
could easily modify this sample so that the proxy requires an API key or OAuth2
token.

## Extra Credit

If you like, you can try:

- modify the `<Audience>` to specify a different URL
- remove the `<Authentication>` element entirely

... and in each case, re-import and re-deploy the proxy, then re-try the
request.  What results do you expect to see?

You can also try modifying the app.js logic, to do something more interesting -
read from a storage bucket or a database, etc.  Be sure to re-deploy the Cloud
Function after each modification.

If you do modify and redeploy the Cloud Function, you don't _necessarily_ need
to also modify the API Proxy.

## Conclusion

Congratulations! You've successfully demonstrated an Apigee Proxy that connects
to a Cloud Function. You used multiple distinct Service Accounts to identify the
Cloud Function and the Apigee API Proxy.

## Cleanup

If you want to clean up the artifacts from this example in your Apigee
organization, run the cleanup script:

```sh
./clean-cloud-functions.sh
```
