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

//go:generate protoc  --proto_path=. --go_out=./generated/pb --go-grpc_out=./generated/pb  --go_opt=paths=source_relative --go-grpc_opt=paths=source_relative greeter.proto

import (
	"context"
	"fmt"
	"github.com/apigee-samples/grpc-web/app/pkg/grpc/generated/pb"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type GRPCServer struct {
	pb.UnimplementedGreeterServer
}

func (s *GRPCServer) SayHello(_ context.Context, req *pb.HelloRequest) (*pb.HelloReply, error) {
	if req.Name == "" {
		return nil, status.Error(codes.FailedPrecondition, "name is required")
	}

	res := pb.HelloReply{}
	res.Message = fmt.Sprintf("Hello %s !", req.Name)
	return &res, nil
}
