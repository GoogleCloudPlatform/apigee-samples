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
# Apigee Extension Processor (HTTP) Tutorial

## Introduction

This sample guides you through the setup process for using the [Apigee Extension Processor](https://cloud.google.com/apigee/docs/api-platform/service-extensions/extension-processor-overview).

Let's get started!

---

## Configure Environment

1. **Authenticate:**  
    Ensure your active GCP account is selected in Cloud Shell.

    ```bash
    gcloud auth login
    ```

2. **Navigate:**  
    Change to the project directory.

    ```bash
    cd extension-processor-http
    ```

3. **Configure and Source Environment:**  
    Edit `env.sh` with your settings.
    <walkthrough-editor-open-file filePath="extension-processor-http/env.sh">Click here to open `env.sh`</walkthrough-editor-open-file>.

    Then, source it to apply the settings:

    ```bash
    source ./env.sh
    ```

---

## Create External Global Load Balancer

In this step, let's create a new **GCP External Global Load Balancer** that uses an **Internet Network Endpoint Group (NEG)** pointing to `httpbin.org`.

1. **Run the script:**  

    ```bash
    ./1-create-load-balancer.sh
    ```

    This script outputs the load balancer's hostname (`$LB_HOSTNAME`).<br />
    ⏳ **Deployment takes about 15 minutes** due to google managed certificate provisioning. <br />
    The certificate hostname uses the nip.io DNS service. (i.e. `{IP}.nip.io`, where `{IP}`is the Load Balancer IP address.)<br />
2. **Test the load balancer:**  
    Execute the following cURL command:

    ```bash
    curl -v -X GET https://$LB_HOSTNAME/json
    ```

    ✅ You should see an HTTP `200` response with a JSON body.

    ⚠️ If you get an **SSL Error**, wait 15 minutes and retry.

---

## Create Apigee Resources

Next, let's set up your **Apigee Environment**, **API Proxy**, and **API Product** by running the following scripts.

1. **Create and Attach Environment:**  
    Run the script to create an Apigee Environment (with the extension processor enabled) and attach it to a runtime instance:

    ```bash
    ./2-create-environment.sh
    ```

2. **Create and Deploy API Proxy:**  
    Run the script to create an API proxy named `extproc-proxy` and deploy it to the new environment:

    ```bash
    ./3-create-api-proxy.sh
    ```

    This script configures the API Proxy to include a **Verify API Key** policy, which means API calls will require a valid API Key.<br />

3. **Create API Product:**  
    Run the script to create an API Product named `extproc-product` that includes the `extproc-proxy` API Proxy:

    ```bash
    ./4-create-api-product.sh
    ```

**Important:** API traffic is **not yet routed** through Apigee. You will configure this routing in the next step.

---

## Create Service Extension

Next, let's modify the External Global Load Balancer by adding a Service Extension to route traffic through the Apigee runtime.

1. **Add Service Extension:**  
    Run the script:

    ```bash
    ./5-create-service-extension.sh
    ```

2. **Test the Updated Load Balancer:**  
    Run the cURL command:

    ```bash
    curl -v -X GET https://$LB_HOSTNAME/json
    ```

    You should see the request **denied** with an API Key validation fault.<br />

    ✅ This confirms traffic is now routed through the Apigee runtime, and the `VA-VerifyAPIKey` policy in the `extproc-proxy` API Proxy is triggering the fault.

In the next step, you will obtain an API Key and retry this request.

---

## Create Developer App

Finally, let's create an Apigee Developer App, `extproc-app`, and subscribe it to the `extproc-product` API Product.
Typically, API consumers create apps via a Developer Portal.
For this tutorial, instead, you'll create the app directly using the [Apigee CLI](https://github.com/apigee/apigeecli).

1. **Create the Developer App:**  
    Run the following script:

    ```bash
    ./6-create-developer-app.sh
    ```

    The script will output the API Key for the new app. <br />

2. **Test the Service with the API Key:**  
    Set the API Key as an environment variable.

    ```bash
    export DEVELOPER_APP_API_KEY="<YOUR_DEVELOPER_APP_KEY>"
    ```

    Then, send the test request:

    ```bash
    curl -v -X GET "https://${LB_HOSTNAME}/json?apikey=${DEVELOPER_APP_API_KEY}"
    ```

🎉 If you see an HTTP 200 response, congrats, you've completed this tutorial!

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
