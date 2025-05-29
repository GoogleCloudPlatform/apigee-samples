<!--
 Copyright 2025 Google LLC

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
# Apigee Extension Processor (gRPC) Tutorial

## Introduction

This sample guides you through the setup process for using the [Apigee Extension Processor](https://cloud.google.com/apigee/docs/api-platform/service-extensions/extension-processor-overview).

Let's get started!

---

## Configure Environment


1.  **Authenticate:**  
    Ensure your active GCP account is selected in Cloud Shell.
    ```bash
    gcloud auth login
    ```

2.  **Navigate:**  
    Change to the project directory.
    ```bash
    cd extension-processor-grpc
    ```
    
3.  **Install grpcurl tool**
    ```bash
    ./download-and-install-grpcurl.sh
    ```
    Add it to your $PATH
    ```bash
    export PATH="$HOME/.grpcurl/bin:${PATH}"
    ```

4.  **Configure and Source Environment:**  
    Edit `env.sh` with your settings.
    <walkthrough-editor-open-file filePath="extension-processor-grpc/env.sh">Click here to open `env.sh`</walkthrough-editor-open-file>.

    Then, source it to apply the settings:
    ```bash
    source ./env.sh
    ```

---

## Deploy gRPC backend-service

In this step, let's deploy a sample gRPC service to Cloud Run.

```bash
./1-create-grpc-service.sh
```

Once the deployment is complete, it will print out the hostname for the gRPC service.

Export `$CR_HOSTNAME` variable that was output by the script.

```bash
export CR_HOSTNAME="..."
```

Then, use the following command to test it out:

```bash
export ID_TOKEN=$(gcloud auth print-identity-token)
```

```bash
grpcurl -H "Authorization: Bearer ${ID_TOKEN}" \
   ${CR_HOSTNAME}:443 \
   helloworld.Greeter.SayHello
```

You can also try sending a request the `CountTo` RPC to test response streaming:

```bash
grpcurl -H "Authorization: Bearer ${ID_TOKEN}" \
        -d '{"to":5}' \
        ${CR_HOSTNAME}:443 helloworld.Greeter.CountTo
```
---

## Create External Global Load Balancer

In this step, we will disable direct external access to the gRPC service, and instead expose it through a Load Balancer.

This will allow us to later apply Apigee API Management policies to this gRPC service (through a Service Extension).

So, let's create a new **GCP External Global Load Balancer** that uses a **Serverless Network Endpoint Group (NEG)** pointing to the gRPC service.

1.  **Run the script:**  
    ```bash
    ./2-create-load-balancer.sh
    ```
    This script outputs the load balancer's hostname.<br />

    Export `$LB_HOSTNAME` variable that was output by the script.
    
    ```shell
    export LB_HOSTNAME="..."
    ```
    <br />
    ⏳ **Deployment takes about 15 minutes** (due to external certificate provisioning).<br />
2.  **Test the gRPC service through the balancer:**  

    Now, we are going to test the gRPC service again, but through the Load Balancer URL.<br />

    Execute the following grpcurl commands:
    ```bash
    export ID_TOKEN=$(gcloud auth print-identity-token)
    ```
    ```bash
    grpcurl -H "Authorization: Bearer ${ID_TOKEN}" \
        ${LB_HOSTNAME}:443 \
        helloworld.Greeter.SayHello
    ```
    ✅ You should see a success response.

    ⚠️ If you get a **TLS error**,  wait 15 minutes and retry.

    ℹ️ Notice that you still needed to pass an `Authorization` header with an ID token.
    This is because Global Load Balancer is simply passing through the calls to Cloud Run.
    That's fine for now. Later, once we add Apigee into the mix, the API Proxy itself will inject the `Authorization` header.

---

## Create Apigee Resources

Next, let's set up your **Apigee Environment**, **API Proxy**, and **API Product** by running the following scripts.

1.  **Create and Attach Environment:**  
    Run the script to create an Apigee Environment (with the extension processor enabled) and attach it to a runtime instance:
    ```bash
    ./3-create-environment.sh
    ```
    
    Notice that the new environment has a special property `apigee-service-extension-enabled` set.

    This tells the Apigee runtime that this is a special environment meant for use with Service Extensions.

2.  **Create and Deploy API Proxy:**  
    Run the script to create an API proxy named `extproc-proxy` and deploy it to the new environment:
    ```bash
    ./4-create-api-proxy.sh
    ```
    The API Proxy includes a **Verify API Key** policy. This means API calls will require a valid API Key.<br /><br />
    The API Proxy also contains a policy that mints a Google Cloud Identity Token and injects the "Authorization" header for Cloud Run to use.

3.  **Create API Product:**  
    Run the script to create an API Product named `extproc-product` that includes the `extproc-proxy` API Proxy:
    ```bash
    ./5-create-api-product.sh
    ```

**Important:** API traffic is **not yet routed** through Apigee. You will configure this routing in the next step.

---

## Create Service Extension


Next, let's modify the External Global Load Balancer by adding a Service Extension to route traffic through the Apigee runtime.

1.  **Add Service Extension:**  
    Run the script:
    ```bash
    ./6-create-service-extension.sh
    ```
    
    Once the Service Extension is applied to the Load Balancer, it takes about a minute to take effect.

2.  **Test the Updated Load Balancer:**  
    Run the grpcurl command:
    ```bash
    grpcurl ${LB_HOSTNAME}:443 helloworld.Greeter.SayHello
    ```
    You should see the request **denied** due to API Key validation fault.<br />

    ✅ This confirms traffic is now routed through the Apigee runtime, and the `VA-VerifyAPIKey` policy in the `extproc-proxy` API Proxy is triggering the fault.

In the next step, you will obtain an API Key and retry this request.

---

## Create Developer App 

Finally, let's create an Apigee Developer App, `extproc-app`, and subscribe it to the `extproc-product` API Product.<br /> 
Typically, API consumers create apps via a Developer Portal.<br />
For this tutorial, instead, you'll create the app directly using the [Apigee CLI](https://github.com/apigee/apigeecli).

1.  **Create the Developer App:**  
    Run the following script:
    ```bash
    ./7-create-developer-app.sh
    ```
    The script will output the API Key for the new app. <br />

    Export the `$DEVELOPER_APP_KEY` variable that was output by the script:
    ```shell
    export DEVELOPER_APP_KEY="..."
    ```

2.  **Test the Service with the API Key:**  

    Run the following command to send the request:
    ```bash
    grpcurl -H "apikey: ${DEVELOPER_APP_API_KEY}" \
        ${LB_HOSTNAME}:443 helloworld.Greeter.SayHello
    ```

    You can also try sending a request the `CountTo` RPC to test response streaming:
    
    ```bash
    grpcurl -H "apikey: ${DEVELOPER_APP_API_KEY}" \
            -d '{"to":5}' \
            ${LB_HOSTNAME}:443 helloworld.Greeter.CountTo
    ```

🎉 If you see a success response, congrats, you've completed this tutorial!

---

## Conclusion & Cleanup

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully created a Google Cloud External Load Balancer and configured it to use 
the Apigee Extension Processor.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

To clean up the artifacts created:


To clean up the artifacts created, source your `env.sh` script

```bash
source ./env.sh
```

Then, run the following scripts to clean up the resources created earlier.

```bash
./clean-service-extension.sh
```
```bash
./clean-developer-app.sh
```
```bash
./clean-api-product.sh
```
```bash
./clean-api-proxy.sh
```
```bash
./clean-environment.sh
```
```bash
./clean-load-balancer.sh
```
```bash
./clean-grpc-service.sh
```

