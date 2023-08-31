# Websockets

---
This sample shows how to implement a websockets API proxy in Apigee fronting a websockets echo server running in Cloud Run.

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `websockets` directory in the Cloud shell.

```sh
cd websockets
```

---

## Create a websockets backend in Cloud Run

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

```
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

If this command is successful it should deploy the websockets server into Cloud Run and return the service URL.

Go ahead and save the Service URL, since it will be used in the next step when we configure the Apigee proxy.

```sh
CLOUD_RUN_SERVICE_URL=$(gcloud run services describe websockets-echo-server --platform managed --region $REGION --format 'value(status.url)' | sed -E 's/http.+\///')
export CLOUD_RUN_SERVICE_URL
```



---

## Deploy Apigee components

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="websockets/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

Next, let's create and deploy the Apigee resources necessary to test the websockets proxy. (Make sure you are on the root folder of the websockets repository):

```sh
./deploy.sh
```

This script creates a sample websockets API Proxy. The script also tests that the deployment and configuration has been sucessful.


### Test the APIs

The script that deploys the Apigee API proxy, should have printed the proxy information you will need to call the websockets API. If we open the Debug tool inside of Apigee we should be able to see that Apigee is receiving the request from the client and upgrading the protocol from HTTP to Websockets and sending the HTTP status code 101 (switching protocols). You will see this request in the Debug tool for every new connection that is opened. Any subsequent messages won’t show in the tool, since they are being transferred over websockets.



---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully implemented a websockets API proxy in Apigee.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this sample in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```
