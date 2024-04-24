// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"github.com/apigee-samples/grpc-web/app/pkg/grpc"
	"github.com/apigee-samples/grpc-web/app/pkg/grpc-web"
	"os"
)

func main() {
	gRPCWebPort := os.Getenv("PORT")
	if len(gRPCWebPort) == 0 {
		gRPCWebPort = "8080"
	}

	gRPCPort := os.Getenv("GRPC_PORT")
	if len(gRPCPort) == 0 {
		gRPCPort = "10000"
	}

	gRPCServer, err := grpc.Start(gRPCPort)
	if err != nil {
		return
	}

	err = grpc_web.Start(gRPCServer, gRPCWebPort)

}
