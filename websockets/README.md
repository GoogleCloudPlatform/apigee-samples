# Websockets in Apigee

This sample shows how to deploy a sample websockets echo server in [Cloud Run](https://cloud.google.com/run) and how to use Apigee to expose that service to developers securely. For more information on how to use websockets in Apigee, please refer to the official [documentation](https://cloud.google.com/apigee/docs/api-platform/develop/websocket-config).

## About websockets

There are many situations where web interactions need to happen in real time, such as gaming, communications, financial transactions, and other high-throughput activities.

WebSocket is a protocol that provides a full-duplex communications channel between a web client and web server over a single TCP connection. The WebSocket protocol uses the HTTP protocol to establish the connection between the client and server. Once established, the client and server then use the WebSocket protocol to send and receive data.

The WebSockets [spec](https://websockets.spec.whatwg.org/) and protocol is maintained by the W3C.

## How it works

In Apigee and Apigee hybrid, environment groups provide routing to environments and define the hostnames on which API proxies are exposed. Environment groups support both the HTTP and WS protocols natively. You do not have to create a special environment group or any special configuration to use WebSockets. Rather, it is up to the client to request a protocol upgrade from HTTP to WS by including the Upgrade request header. An upgrade request made to an API proxy endpoint returns a 101 Switching Protocols response. Further requests and responses are made bidirectionally on the open WebSockets connection, until it is closed.

### Policy support

With a WebSockets connection, you can only use the [Verify API Key](https://cloud.google.com/apigee/docs/api-platform/reference/policies/verify-api-key-policy) and [OAuthV2](https://cloud.google.com/apigee/docs/api-platform/reference/policies/oauthv2-policy) policies in your API proxy. All other policies are ignored.

### Revoking the connection

The WebSockets connection is closed when:

* The proxy endpoint receives a request without an API key or OAuth token.
* The proxy endpoint receives a request with an expired or invalid API key or OAuth token.
* The WebSockets connection times out.

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
    * docker

5. Make sure that the following GCP APIs are enabled:
    * Cloud Run API
    * Container Registry API

6. Make sure that you have the following permissions:

    * [Artifact Registry Repository Administrator](https://cloud.google.com/iam/docs/understanding-roles#artifactregistry.repoAdmin) role  (roles/artifactregistry.repoAdmin)
    * [Cloud Run Developer](https://cloud.google.com/run/docs/reference/iam/roles) role (roles/run.developer)

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=websockets/docs/cloudshell-tutorial.md)

## Setup instructions

### Create a websockets backend in Cloud Run

Enable the Cloud Run API and Container Registry API:

```bash
gcloud services enable run.googleapis.com containerregistry.googleapis.com
```

Create a Docker image:
In Cloud Shell, clone the websockets repo

```sh
export PROJECT=$GOOGLE_CLOUD_PROJECT
mkdir websockets-backend
cd websockets-backend
git clone https://github.com/websockets/websocket-echo-server.git
cd websocket-echo-server
```

Build the Docker image and then list the images created in CloudShell:

```sh
docker build .
docker images -a
```

Save the imageid from above to an environment variable and run the Docker image locally:

```sh
export DOCKER_IMAGE=<imageid>
docker run -e BIND_PORT=8080 --expose 8080 -d -p 8080:8080 $DOCKER_IMAGE
```

Open a second tab in your CloudShell and connect to your localhost to verify that the server is working. (We will be installing wscat for this test):

```sh
npm install -g wscat
wscat --connect ws://localhost:8080
```

You should be able to type anything and receive an echo response from the server:

```sh
Connected (press CTRL+C to quit)
> hello
< hello
```

Once you verified that the image is working, you can close the second tab.
Now let's create a global Artifact Registry and configure Docker to use the Artifact Registry:

```sh
gcloud artifacts repositories create websocketsdemo \
    --repository-format=Docker \
    --location=us \
    --description="Websockets Demo repo"

gcloud auth configure-docker us-docker.pkg.dev
```

Tag the Docker image, Push the Docker image, and create a Cloud Run service from the Docker image:
Optional: Change REGION= to a region closest to your Apigee instance

```sh
export REGION=us-central1
docker tag $DOCKER_IMAGE us-docker.pkg.dev/$PROJECT/websocketsdemo/websockets-echo-server
docker push us-docker.pkg.dev/$PROJECT/websocketsdemo/websockets-echo-server
gcloud run deploy \
--set-env-vars BIND_PORT=8080 \
websockets-echo-server \
--image us-docker.pkg.dev/$PROJECT/websocketsdemo/websockets-echo-server \
 --platform managed --allow-unauthenticated \
--region $REGION
```

If this command is successful it should deploy the websockets server to Cloud Run and return the service URL.

Go ahead and save the Service URL, since it will be used in the next step when we configure the Apigee proxy.

```bash
CLOUD_RUN_SERVICE_URL=$(gcloud run services describe websockets-echo-server --platform managed --region $REGION --format 'value(status.url)' | sed -E 's/http.+\///')
export CLOUD_RUN_SERVICE_URL
```

### Deploy Apigee Resources

1. Clone the `apigee-samples` repo, and switch to the `websockets` directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/websockets
```

2. Edit the `env.sh` file and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `CLOUD_RUN_SERVICE_URL` the service URL for the Cloud Run service running the websockets echo server

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee API proxies, products and apps

```bash
./deploy.sh
```

## Testing the websockets Proxy

The script that deploys the Apigee API proxy, should have printed the proxy URL and API keys you will need to call the websockets API. If we open the Debug tool inside of Apigee we should be able to see that Apigee is receiving the request from the client and upgrading the protocol from HTTP to Websockets and sending the HTTP status code 101 (switching protocols). You will see this request in the Debug tool for every new connection that is opened. Any subsequent messages won’t show in the tool, since they are being transferred over websockets.

To call the API manually use wscat or another websockets client:

```bash
wscat -c wss://$PROXY_URL?apikey=$CLIENT_ID_1
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```
