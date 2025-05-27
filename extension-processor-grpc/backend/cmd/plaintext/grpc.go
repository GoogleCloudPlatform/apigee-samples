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

package main

import (
	"fmt"
	"github.com/labstack/echo/v4"
	"github.com/micovery/extension-processor-grpc/backend/pkg/greeter"
	"github.com/micovery/extension-processor-grpc/backend/pkg/greeter/generated/pb"
	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

func main() {
	port := os.Getenv("PORT")
	if len(port) == 0 {
		port = "8080"
	}

	e := echo.New()
	h2s := &http2.Server{
		MaxConcurrentStreams: 250,
		MaxReadFrameSize:     1048576,
		IdleTimeout:          10 * time.Second,
	}

	grpcServer := grpc.NewServer([]grpc.ServerOption{}...)
	reflection.Register(grpcServer)
	pb.RegisterGreeterServer(grpcServer, &greeter.GRPCServer{})

	s := http.Server{
		Addr: fmt.Sprintf(":%s", port),
		Handler: h2c.NewHandler(http.HandlerFunc(func(resp http.ResponseWriter, req *http.Request) {
			if req.ProtoMajor == 2 && strings.HasPrefix(req.Header.Get("content-type"), "application/grpc") {
				grpcServer.ServeHTTP(resp, req)
				return
			}
			e.ServeHTTP(resp, req)
		}), h2s),
	}

	fmt.Printf("Starting plaintext gRPC server on port %s\n", port)
	if err := s.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
