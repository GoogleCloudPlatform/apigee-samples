#  Copyright 2024 Google LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

FROM golang:1.22 as builder

COPY ./ /src
WORKDIR /src

RUN apt-get update && apt-get install -y protobuf-compiler
RUN mkdir bin && \
    go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28 && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2 && \
    go generate ./... && \
    go build -o ./bin/go-grpc-web ./cmd/

FROM golang:1.22

ARG PORT=8080
EXPOSE ${PORT}

LABEL org.opencontainers.image.url='https://github.com/GoogleCloudPlatform/apigee-samples/grpc-web/app' \
      org.opencontainers.image.documentation='https://github.com/GoogleCloudPlatform/apigee-samples/grpc-web/app' \
      org.opencontainers.image.source='https://github.com/GoogleCloudPlatform/apigee-samples//grpc-web/app' \
      org.opencontainers.image.vendor='Google LLC' \
      org.opencontainers.image.licenses='Apache-2.0' \
      org.opencontainers.image.description='This is sample backend app for gRPC-Web'


COPY --from=builder /src/bin/* /usr/local/bin/

ENTRYPOINT [ "go-grpc-web" ]

