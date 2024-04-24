<!--
  Copyright 2024 Google LLC

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->
## gRPC-Web sample backend

This directory contains sample code for creating a gRPC server + gRPC-web wrapper in Go, that can be used as the backend for an Apigee API Proxy.

## Table of Contents

- [How to build the app locally](#how-to-build-the-app-locally)
- [How to run the app locally](#how-to-run-the-app-locally)
- [How to run the app locally with Docker](#how-to-run-the-app-locally-with-docker)
- [How to build and deploy to Cloud Run](#how-to-build-and-deploy-to-cloud-run)

## How to build the app locally

First install the protobuf compiler `protoc` , see instructions at: <https://grpc.io/docs/protoc-installation/>

Then, install the [Go plugins](https://grpc.io/docs/languages/go/quickstart/#prerequisites) for `protoc`

```shell
go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2
```

Finally, build the actual application binary

```shell
go generate ./...
go build -o go-grpc-web ./cmd/
```

## How to run the app locally

Use the instructions below to run the sample gRPC servers manually.

```shell
PORT=8080 GRPC_PORT=10000 ./go-grpc-web
````

## How to run the app locally with Docker

First build the docker image

```shell
docker build -t grpc-web-app .
```

Then, run it

```shell
docker run --rm -it -p 8080:8080 grpc-web-app
```

## How to build and deploy to Cloud Run

You can run the application within a container in Cloud Run.
There is a docker file included [/Dockerfile](/grpc-web/app/Dockerfile) that can be used
to build and deploy to Cloud Run.

The build will run remotely using Cloud Build, and the container image will be stored in
repository automatically in your GCP Project.

The gRPC-Web server will be available publicly without authentication, use this for testing only.

First authenticate with gcloud, and set your project using `gcloud`

```shell
gcloud auth login
gcloud config set project YOUR_GCP_POJECT
```

Then, run the following script to build, and deploy to Cloud Run

```shell
export REGION=us-west1
./deploy-grpc-web-cloud-run.sh
```

Once build is complete, Cloud Run will give you the URL to access the container, e.g. <https://apigee-grpc-web-backend-p57ysoduga-uw.a.run.app>

You can use `cURL` to verify it's working as expected.

**Note** Since this is a gRPC-Web call, both the request and response payloads are actually protobufs that have been base64 encoded.

```shell
curl 'https://apigee-grpc-web-backend-p57ysoduga-uw.a.run.app/helloworld.Greeter/SayHello' \
  -H 'content-type: application/grpc-web-text' \
  --data-raw 'AAAAAAYKBGhvbWU='
```
