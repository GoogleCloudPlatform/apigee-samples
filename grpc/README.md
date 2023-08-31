# gRPC on Apigee

This sample shows how to use Apigee in front of your gRPC backends.
For this example we will be using Cloud Run to host a gRPC server and configure it as a target server in Apigee. Apigee will act as a simple reverse proxy in front of the gRPC backend. For more detailed information on using gRPC proxies in Apigee, please refer to the official [documentation](https://cloud.google.com/apigee/docs/api-platform/fundamentals/build-simple-api-proxy#creating-grpc-api-proxies).



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


# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=grpc/docs/cloudshell-tutorial.md)

## Setup instructions

## Create a gRPC backend

In this first step we will create a docker image with the hello world application.
Go to Cloud Shell, and clone the gRPC repo:

```sh
git clone https://github.com/grpc/grpc.git
cd grpc/examples/python/helloworld
```

Modify the server code to run on port 8080 (required by Cloud Run). Use vi or nano to edit the file and modify the port on line 30 to 8080:

```sh
vi greeter_server.py
```

Create a Dockerfile for the Hello World example:

```sh
touch Dockerfile
touch requirements.txt
```

Open the file in the editor and add the following code to the Dockerfile:

```sh
vi Dockerfile
```

```
FROM python:3.7

WORKDIR /app

COPY . .

RUN pip install -r requirements.txt

EXPOSE 8080

CMD ["python", "greeter_server.py"]

```


Edit the requirements file in the editor and add the following lines:

```sh
vi requirements.txt
```

```
grpcio
protobuf
```


Build the Docker image and then list the images created:

```sh
docker build .
docker images -a
```


Save the imageid from the previous step to an environment variable and run the Docker image locally:

```sh
export DOCKER_IMAGE="<YOUR_IMAGE_ID_FROM_ABOVE>"
docker run -p 8080:8080 -it $DOCKER_IMAGE
```


Open up a 2nd cloud shell session or terminal tab. Use grpcurl to ensure the service is working. grpcurl expects to send Service.Method to gRPC endpoints and validates that against the proto file. If you look at the protofile referenced, you’ll see that the package keyword is used to specify the package name for the service. The package name is used to uniquely identify the service.  In this case, the fully qualified name of the service is helloworld.Greeter

```sh
grpcurl -plaintext -import-path $HOME/grpc/examples/protos -proto helloworld.proto -d '{"name":"Guest"}' localhost:8080 helloworld.Greeter/SayHello
```

If you get a response like the one below, the Docker image is working!:

```
{
    "message": "Hello, Guest!"
}
```

Once the image is working, you can close the 2nd tab. Let's go back to the first shell and stop the image using `Ctrl+C`. 
Now let's create a global Artifact Registry and configure Docker to use the Artifact Registry:

```sh
gcloud artifacts repositories create grpcdemo \
    --repository-format=Docker \
    --location=us \
    --description="gRPC Demo repo"

gcloud auth configure-docker us-docker.pkg.dev

```


Tag the Docker image, Push the Docker image, and create a Cloud Run service from the Docker image.

```sh
export REGION=us-central1
docker tag $DOCKER_IMAGE us-docker.pkg.dev/$PROJECT/grpcdemo/my-grpc-service
docker push us-docker.pkg.dev/$PROJECT/grpcdemo/my-grpc-service
gcloud run deploy my-grpc-service --image us-docker.pkg.dev/$PROJECT/grpcdemo/my-grpc-service --platform managed --use-http2 --allow-unauthenticated --region $REGION

```

Once the deployment completes, store the service URL in an environment variable:

```sh
CLOUD_RUN_SERVICE_URL=$(gcloud run services describe my-grpc-service --platform managed --region $REGION --format 'value(status.url)' | sed -E 's/http.+\///')
export CLOUD_RUN_SERVICE_URL
```

```sh
grpcurl -import-path $HOME/cloudshell_open/apigee-samples/grpc/grpc-backend/grpc/examples/protos -proto helloworld.proto -d '{"name":"Guest"}' $CLOUD_RUN_SERVICE_URL:443 helloworld.Greeter/SayHello

```

If you get a successful response you’re ready to update the GCP LB to support gRPC.


## Update Load Balancer

For this step, we’ll create a unique path for gRPC traffic. We'll use ssl certificate and a route rule for the domain name using the nip.io service. This assumes that your backend is using a PSC NEG connected to Apigee.  If you’re using MIGs, you can follow the [public documentation](https://cloud.google.com/apigee/docs/api-platform/fundamentals/build-simple-api-proxy#creating-grpc-api-proxies) for these steps.


Identify the and forwarding rule name, IP and target of your load balancer:

```sh
FORWARDING_RULE=$(gcloud compute forwarding-rules list --format="value(name)")
IP_ADDRESS=$(gcloud compute forwarding-rules list --format="value(IPAddress)")
TARGET_PROXY=$(gcloud compute forwarding-rules list --format="value(target)")
```


Store the URL Map and SSL certificate names by getting the details of the Target Proxy:

```sh
URL_MAP=$(gcloud compute target-https-proxies describe $TARGET_PROXY --format="value(urlMap.basename())")
SSL_CERT=$(gcloud compute target-https-proxies describe $TARGET_PROXY --format="value(sslCertificates.basename())")
```

Identify your current SSL certificate domain names:

```sh
gcloud compute ssl-certificates describe $SSL_CERT  --format json | jq .managed.domains
```

Create a new certificate that includes grpc specific nip.io dns name:

```sh
export DOMAINS="<EXISTING_APIGEE_HOSTNAME_FROM_ABOVE>","grpc.$IP_ADDRESS.nip.io"
```

```sh
gcloud compute ssl-certificates create apigee-ssl-grpc \
       --domains $DOMAINS
```

Update the target proxy to use the new certificate:

```sh
gcloud compute target-https-proxies update $TARGET_PROXY --ssl-certificates apigee-ssl-grpc
```

Create a Backend service that supports HTTP2:

```sh
gcloud compute backend-services create apigee-grpc \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --protocol=HTTP2 \
  --global --project=$PROJECT
```

Find the name of the Apigee NEG:

```sh
gcloud compute network-endpoint-groups list
```

Add the backend service to the Apigee (NEG):

```sh
export APIGEE_NEG="<NEG_NAME_FROM_ABOVE>"
gcloud compute backend-services add-backend apigee-grpc \
  --network-endpoint-group=$APIGEE_NEG \
  --network-endpoint-group-region="<LOCATION_FROM_ABOVE>" \
  --global --project=$PROJECT
```


Edit the URL map:

```sh
gcloud compute url-maps edit $URL_MAP
```

The previous command will open the file in vi. Edit the values below and paste them under the defaultService.:

```
hostRules:
- hosts:
  - grpc.<IP-ADDRESS>.nip.io
  pathMatcher: grpc-domain
name: apigee-lb
pathMatchers:
- defaultService: https://www.googleapis.com/compute/v1/projects/<PROJECT_ID>/global/backendServices/apigee-grpc
  name: grpc-domain

```

---

## Deploy Apigee components

1. Clone the `apigee-samples` repo, and switch the `grpc` directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/grpc
```

2. Edit the `env.sh` file and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created
* `CLOUD_RUN_SERVICE_URL` the service URL for the Cloud Run service running the websockets echo server
* `ENV_GROUP_NAME` the environment group name where the gRPC proxy hostname will be configured
* `ENV_GROUP_HOSTNAME_GRPC` the gRPC hostname (for example grpc.$IP_ADDRESS.nip.io)
* `GRPC_TARGET_SERVER_NAME` name of the gRPC target server

Now source the `env.sh` file

```bash
source ./env.sh
```

Let's run the script that will create and deploy the Apigee resources necessary to test the gRPC functionality.


```sh
./deploy.sh
```

This script creates a sample API Proxy, a Developer, an API product, and a gRPC target server. The script also tests that the deployment and configuration has been sucessful.


### Test the APIs

The script that deploys the Apigee API proxies prints the proxy and other information you will need to run the commands below.

Set the proxy URL:
```sh
export PROXY_URL=<replace with script output>
```

Run the following grpcurl command:
```sh
grpcurl -import-path $HOME/grpc/examples/protos -proto helloworld.proto -d '{"name":"Guest"}' $ENV_GROUP_HOSTNAME_GRPC:443 helloworld.Greeter/SayHello
```


## Manually Testing the gRPC Proxy

To run the tests, first retrieve Node.js dependencies with:
```sh
npm install
```
Ensure the following environment variables have been set correctly:
* `PROXY_URL`

and then run the tests:

```sh
npm run test
```

## Example Requests
To manually test the proxy, make requests using grpcurl:

```sh
grpcurl -import-path $HOME/grpc/examples/protos -proto helloworld.proto -d '{"name":"Guest"}' $APIGEE_HOST:443 helloworld.Greeter/SayHello
```


## Cleanup
If you want to clean up the artefacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```