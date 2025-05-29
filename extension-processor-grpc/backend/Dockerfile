# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM golang:1.24.3-alpine

LABEL maintainer="miguelmendoza@google.com.com"

ARG PORT=8080
EXPOSE ${PORT}

RUN apk add --no-cache curl zip unzip protobuf protobuf-dev grpc grpc-plugins

RUN mkdir /app

COPY "pkg" /app/pkg/
COPY "cmd" /app/pkg/
COPY "go.mod" /app/
COPY "go.sum" /app/

WORKDIR /app
RUN echo "*** Build application ***" \
    && PATH="$PATH:$(go env GOPATH)/bin" \
    && go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28 \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2 \
    && go generate ./... \
    && go build -o grpc-greeter-plaintext ./pkg/plaintext

WORKDIR /

ENTRYPOINT ["/app/grpc-greeter-plaintext"]