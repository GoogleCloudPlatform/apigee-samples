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

package grpc_web

import (
	"fmt"
	"github.com/improbable-eng/grpc-web/go/grpcweb"
	"github.com/labstack/echo/v4"
	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"net/http"
)

func NewEcho(gRPCServer *grpc.Server, grpcWebPort string) (*echo.Echo, error) {
	echoServer := echo.New()

	echoHandler := echoServer
	wrappedGrpc := grpcweb.WrapServer(gRPCServer)

	//override server handler to intercept grpc-web requests (content-type: application/grpc-web)
	echoServer.Server = &http.Server{
		Addr: fmt.Sprintf(":%s", grpcWebPort),
		Handler: http.HandlerFunc(func(resp http.ResponseWriter, req *http.Request) {
			resp.Header().Set("Access-Control-Allow-Headers", "*")
			resp.Header().Set("Access-Control-Allow-Origin", "*")

			if wrappedGrpc.IsGrpcWebRequest(req) {
				wrappedGrpc.ServeHTTP(resp, req)
				return
			}

			echoHandler.ServeHTTP(resp, req)
		}),
	}

	echoServer.HideBanner = true
	return echoServer, nil
}

func Start(gRPCServer *grpc.Server, grpcWebPort string) error {
	echo, err := NewEcho(gRPCServer, grpcWebPort)
	if err != nil {
		panic(err)
	}

	fmt.Printf("⇨ http server started on [::]%s\n", echo.Server.Addr)
	err = echo.Server.ListenAndServe()
	if !errors.Is(err, http.ErrServerClosed) {
		fmt.Println("(http): server halted forcefully")
		panic(err)
	}
	fmt.Println("(http): server halted gracefully")
	return nil
}
