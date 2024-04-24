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

package grpc

import (
	"fmt"
	"github.com/apigee-samples/grpc-web/app/pkg/grpc/generated/pb"
	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
	"net"
)

func Start(gRPCPort string) (*grpc.Server, error) {

	gRPCServer := grpc.NewServer([]grpc.ServerOption{}...)
	reflection.Register(gRPCServer)
	pb.RegisterGreeterServer(gRPCServer, &GRPCServer{})

	go func() {
		lis, err := net.Listen("tcp", fmt.Sprintf(":%s", gRPCPort))
		if err != nil {
			err = errors.New(fmt.Sprintf("could not listen on http port %s. %v", gRPCPort, err))
			panic(err)
		}

		fmt.Printf("⇨ gRPC server started on [::]:%s\n", gRPCPort)
		err = gRPCServer.Serve(lis)
		if err != nil {
			err = errors.New(fmt.Sprintf("could not serve gRPC on port %s. %v", gRPCPort, err))
			panic(err)
		}
	}()

	return gRPCServer, nil
}
