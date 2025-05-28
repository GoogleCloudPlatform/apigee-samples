// Copyright 2025 Google LLC
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

package greeter

//go:generate protoc  --proto_path=. --go_out=./generated/pb --go-grpc_out=./generated/pb  --go_opt=paths=source_relative --go-grpc_opt=paths=source_relative greeter.proto

import (
	"context"
	"fmt"
	"github.com/GoogleCloudPlatform/apigee-samples/extension-processor-grpc/backend/pkg/greeter/generated/pb"
	"time"
)

type GRPCServer struct {
	pb.UnimplementedGreeterServer
}

func (s *GRPCServer) SayHello(_ context.Context, req *pb.SayHelloReq) (*pb.SayHelloRes, error) {
	res := &pb.SayHelloRes{Message: "hello from server"}
	if req.Name != "" {
		res = &pb.SayHelloRes{Message: fmt.Sprintf("Hello %s", req.Name)}
	}
	return res, nil
}

func (s *GRPCServer) CountTo(req *pb.CountToReq, server pb.Greeter_CountToServer) error {
	if req.To <= 0 {
		req.To = 3
	}

	ticker := time.NewTicker(time.Second * 1)

	res := &pb.CountToRes{Count: 0}

Loop:
	for {
		select {
		case <-ticker.C:
			res.Count += 1
			if err := server.Send(res); err != nil {
				return err
			}
			if res.Count == req.To {
				break Loop
			}
		}
	}

	return nil
}
