# llm-inference-gateway

- In this sample, we will cover how Apigee can be configured to provide authentication, authorization, and API management for your inference workloads. Apigee can integrate with [GKE Inference Gateway](https://cloud.google.com/kubernetes-engine/docs/concepts/about-gke-inference-gateway) to provide features like API security, rate limiting, quotas, analytics, and monetization.
- In ths sample, we will create a GKE cluster and configure a GKE Inference Gateway to optimize the serving of generative AI applications and workloads on GKE. 

    **NOTE:** The cluster and the model deployed is just for the demo/sample purposes and not intended for production scale workloads. Please use best practices to deploy your models. The main intention of this sample is to showcase how Apigee can protect your AI workloads that are exposed using GKE Inference Gateways. You can make use of [Google Cluster Toolkit](https://github.com/GoogleCloudPlatform/cluster-toolkit) which makes it easy for customers to deploy AI/ML and HPC environments on Google Cloud

- The sample uses [Apigee Operator for Kubernetes](https://docs.cloud.google.com/apigee/docs/api-platform/apigee-kubernetes/apigee-apim-operator-overview) that allows you to perform API management tasks, such as defining API products and operations, using Kubernetes tools. 
- We will be using `ApigeeBackendService` in this sample that uses Apigee as an extension in the [traffic extension](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/configure-gke-service-extensions#configure-gcp-extensions) resource. 

![architecture](./images/arch.png)

The flow is as follows:
  1. A client request (prompt) is received by the GKE Inference Gateway.
  2. The configured Traffic Extension intercepts the request and forwards the payload to Apigee via the designated `ApigeeBackendService`
  3. Apigee executes the configured Request Flow policies (e.g., authentication, spike arrest, threat protection).
  4. Upon successful verification, Apigee sends the request back to the Inference Gateway which inturn sends it to the target InferencePool where the AI model processes the prompt and generates a response.
  5. The response payload is then routed back to Apigee via the Traffic Extension. Apigee applies Response Flow policies (e.g., data masking, payload validation, quota enforcement).
  6. After final verification by Apigee, the response is returned to the Inference Gateway and ultimately sent back to the calling client.

## Pre-Requisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Enable Google Kubernetes Engine API, Vertex AI API in your project
4. Will require roles to create GKE cluster, Load Balancer, PSC NEGs and create/deploy Apigee resources like proxies, environments, environment groups, etc. For more info, check out this [doc](https://docs.cloud.google.com/apigee/docs/api-platform/apigee-kubernetes/apigee-apim-operator-install#required-roles)
5. Will need a HuggingFace Token. You can sign up for an account at https://huggingface.co and create an Access Token
6. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    - [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    - [helm](https://helm.sh/docs/intro/install/)
    - [apigeecli](https://github.com/apigee/apigeecli)
    - unzip
    - curl
    - jq

## Create a GKE Gateway with the inference extension

1. Edit the values in [env.sh](./env.sh) file and once its saved, run the following command
    ```sh
    source env.sh
    ```
2. Create a new GKE cluster by running the following command
   ```sh
    gcloud container clusters create ${CLUSTER_NAME} --location ${ZONE} \
    --project=${PROJECT_ID} \
    --network=${NETWORK} \
    --subnetwork=${SUBNET} \
    --gateway-api=standard \
    --workload-pool=${PROJECT_ID}.svc.id.goog \
    --machine-type="c2-standard-16" \
    --disk-type="pd-standard" \
    --num-nodes=3 \
    --release-channel="rapid" \
    --monitoring=SYSTEM,DCGM
   ```
    **NOTE:** The cluster and the model deployed is just for the demo/sample purposes and not intended for production scale workloads. Please use best practices to deploy your models. The main intention of this sample is to showcase how Apigee can protect your AI workloads that are exposed using GKE Inference Gateways. You can make use of [Google Cluster Toolkit](https://github.com/GoogleCloudPlatform/cluster-toolkit) which makes it easy for customers to deploy AI/ML and HPC environments on Google Cloud.
3. Once the cluster is up and running, lets configure kubectl command line access by running the following command:
    ```sh
    gcloud container clusters get-credentials $CLUSTER_NAME --location $ZONE --project $PROJECT_ID
    ```
4. Create a Kubernetes secret with the HuggingFace Access Token
   ```sh
    kubectl create secret generic hf-token --from-literal=token=$HF_TOKEN 
   ```
5. We need to install Kubernetes custom resources
   ```sh
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/$RELEASE/config/crd/bases/inference.networking.x-k8s.io_inferenceobjectives.yaml
   ```
6. Deploy a model server
   ```sh
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/$STABLE_MODEL_RELEASE/config/manifests/vllm/cpu-deployment.yaml 
   ```
7. Wait to make sure the deployment is Available
    ```sh
    kubectl wait deployment/vllm-llama3-8b-instruct --for=condition=Available --timeout=5m
    ```
8. Deploy the InferencePool and Endpoint Picker Extension 
    ```sh
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/$RELEASE/config/manifests/inferencepool-resources.yaml
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/$RELEASE/config/manifests/gateway/gke/healthcheck.yaml
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/$RELEASE/config/manifests/gateway/gke/gcp-backend-policy.yaml
    ```
9.  Deploy InferenceObjective
    ```sh
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/$RELEASE/config/manifests/inferenceobjective.yaml
    ```
10. Deploy HTTPRoute
    ```sh
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/$RELEASE/config/manifests/gateway/gke/httproute.yaml
    ```
11. Confirm that the HTTPRoute status conditions include `Accepted=True` and `ResolvedRefs=True`
    ```sh
    kubectl wait httproute/llm-route \
    --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
    --for=jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'=True \
    --timeout=5m
    ```
12. Deploy Gateway
    ```sh
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/$RELEASE/config/manifests/gateway/gke/gateway.yaml
    ```
13. Confirm that the Gateway was assigned an IP address and reports a `Programmed=True` status
    ```sh
    kubectl wait gateway/inference-gateway \
    --for=jsonpath='{.status.addresses[0].value}' \
    --for=condition=Programmed \
    --timeout=5m
    ```
14. Send a Request to Model Backend to Verify Inference Gateway
    ```sh
    IP=$(kubectl get gateway/inference-gateway -o jsonpath='{.status.addresses[0].value}')
    PORT=80

    curl -i ${IP}:${PORT}/v1/completions -H 'Content-Type: application/json' -d '{
        "model": "Qwen/Qwen2.5-1.5B-Instruct",
        "prompt": "What is the capital of France?",
        "max_tokens": 10,
        "temperature": 0
    }'
    ``` 
    You should see a valid response. If you find any issues, please use the troubleshooting [guide](https://docs.cloud.google.com/apigee/docs/api-platform/apigee-kubernetes/apigee-apim-operator-troubleshoot) available in the public docs.

## Install the Apigee APIM Operator

Follow the steps provided in this [doc](https://docs.cloud.google.com/apigee/docs/api-platform/apigee-kubernetes/apigee-apim-operator-install). Please follow the entire step end to end

## Create an ApigeeBackendService

1. Create the `ApigeeBackendService` resource
```sh
cat <<-'EOF' | envsubst > apigee-backendservice.yaml
apiVersion: apim.googleapis.com/v1
kind: ApigeeBackendService
metadata:
  name: apigee-llm-inf-gw
spec:
  apigeeEnv: apim-op-env
  defaultSecurityEnabled: true
  locations:
    - name: $APIGEE_REGION
      network: projects/$APIGEE_ORG/global/networks/$NETWORK
      subnetwork: projects/$APIGEE_ORG/regions/$APIGEE_REGION/subnetworks/$SUBNET
EOF
```
2. Apply the file
```sh
kubectl apply -f apigee-backendservice.yaml
```

## Create a GCPTrafficExtension resource

1. Create the `GCPTrafficExtension` resource
```sh
cat <<-'EOF' | envsubst > gcp-traffic-extension.yaml
kind: GCPTrafficExtension
apiVersion: networking.gke.io/v1
metadata:
  name: demo-apigee-extension
spec:
  targetRefs:
  - group: "gateway.networking.k8s.io"
    kind: Gateway
    name: inference-gateway
  extensionChains:
  - name: my-chain1
    matchCondition:
      celExpressions:
      - celMatcher: request.path.startsWith("/")
    extensions:
    - name: my-apigee-extension
      metadata:
          apigee-extension-processor : apigee-llm-inf-gw
          apigee-request-body: 'true'
          apigee-response-body: 'true'
      failOpen: false
      requestBodySendMode: FullDuplexStreamed
      responseBodySendMode: FullDuplexStreamed
      supportedEvents:
      - RequestHeaders
      - RequestBody
      - RequestTrailers
      - ResponseHeaders
      - ResponseBody
      - ResponseTrailers
      timeout: 1s
      backendRef:
        group: "apim.googleapis.com"
        kind: ApigeeBackendService
        name: apigee-llm-inf-gw
EOF
```
2. Apply the file
```sh
kubectl apply -f gcp-traffic-extension.yaml
```
3. Verify the resources are in healthy status
4. Send a Request to Model Backend to Verify Inference Gateway
```sh
IP=$(kubectl get gateway/inference-gateway -o jsonpath='{.status.addresses[0].value}')
PORT=80

curl -i ${IP}:${PORT}/v1/completions -H 'Content-Type: application/json' -d '{
    "model": "Qwen/Qwen2.5-1.5B-Instruct",
    "prompt": "What is the capital of France?",
    "max_tokens": 10,
    "temperature": 0
}'
``` 
You should see an error. Something like

```json
{
    "fault": {
        "faultstring": "Raising fault. Fault name : RF-insufficient-request-raise-fault",
        "detail": {
            "errorcode": "steps.raisefault.RaiseFault"
        }
    }
}
```

## Create the Apigee API Product, Developer and Developer App

1. Create an API Product
```sh
cat <<-'EOF' | envsubst > apigee-apiproduct.yaml
apiVersion: apim.googleapis.com/v1
kind: APIProduct
metadata:
  name: api-inf-gw-product
  namespace: apim
spec:
  approvalType: auto
  description: Inference Gateway API Product
  displayName: api-inf-gw-product
  enforcementRefs:
    - name: apigee-llm-inf-gw
      kind: ApigeeBackendService
      group: apim.googleapis.com
      namespace: default
  attributes:
    - name: access
      value: private
EOF
```
2. Apply the file
```sh
kubectl apply -f apigee-apiproduct.yaml
```
3. Create an API Product Operation Set
```sh
cat <<-'EOF' | envsubst > apigee-apiproduct-ops.yaml
apiVersion: apim.googleapis.com/v1
kind: APIOperationSet
metadata:
  name: item-set
  namespace: apim
spec:
  apiProductRefs:
    - name: api-inf-gw-product
      kind: APIProduct
      group: apim.googleapis.com
      namespace: apim
  quota:
    limit: 5
    interval: 1
    timeUnit: minute
  restOperations:
    - name: "Chat Completions"
      path: /v1/completions
      methods:
        - POST
EOF
```
4. Apply the file
```sh
kubectl apply -f apigee-apiproduct-ops.yaml
```
5. Go to to the Apigee API management page in the Google Cloud console, create a Developer.
6. Once the developer is created, create a Developer App. Make sure to select the `api-inf-gw-product` product. Make a note of the API Key generated
```sh
export APIKEY="APIKEY_TO_SET"
```
7. Send a Request to Model Backend to Verify Inference Gateway
```sh
IP=$(kubectl get gateway/inference-gateway -o jsonpath='{.status.addresses[0].value}')
PORT=80

curl -i ${IP}:${PORT}/v1/completions -H 'Content-Type: application/json' -H "x-api-key: $APIKEY" -d '{
    "model": "Qwen/Qwen2.5-1.5B-Instruct",
    "prompt": "What is the capital of France?",
    "max_tokens": 10,
    "temperature": 0
}'
``` 
You should see a valid response. If you find any issues, please use the troubleshooting [guide](https://docs.cloud.google.com/apigee/docs/api-platform/apigee-kubernetes/apigee-apim-operator-troubleshoot) available in the public docs.