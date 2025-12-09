# llm-function-calling

---

This is a sample on how to deploy a sample Apigee proxy and invoke it within a [function call](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/function-calling) that is available within a Python program that uses the Google Gen AI Python SDK.

[Function Calling in
Gemini](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/function-calling)
allows an app to send a "generate content" request to the Gemini model,
including descriptions of functions available in the app's code. To gather more
context for its generative response, Gemini may respond by instructing the app
to invoke one or more of these functions, specifying the arguments for each one.

This capability makes it easier for developers to build apps that get responses
from generative models that rely on dynamic data that is available only privately or internally.
Function Calling is a building block on which higher-level frameworks like
[Model Context Protocol](https://modelcontextprotocol.io/), aka MCP, are built.

## Steps involved

1. Ensure Authentication
2. Configure and set up environment
3. Provision and Deploy Apigee artifacts
4. Invoke test APIs
5. Run the code in the Python notebook

Let's get started!

---

## Ensure Authentication

Ensure you have an active Google Cloud account selected in the Cloud shell

```sh
gcloud auth login
```

---

## Configure and set up environment.

Navigate to the 'llm-function-calling' directory in the Cloud shell.

```sh
cd llm-function-calling
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Click <walkthrough-editor-open-file filePath="llm-function-calling/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

---

## Provision and Deploy Apigee artifacts

Next, let's deploy the sample to Apigee. Just run

```bash
./deploy-llm-function-calling.sh
```

This will take a minute or two.

Set the `APIKEY` variable as mentioned in the command output.

---

## Verification - Invoke the APIs

To verify that the API is provisioned and available in Apigee, run this curl command:

```sh
curl -i --location "https://$APIGEE_HOST/v1/samples/llm-function-calling/products" -H "Content-Type: application/json" -H "x-apikey: $APIKEY"
```

You should see a list of "products". To see the JSON list formatted:

```sh
curl --silent --location "https://$APIGEE_HOST/v1/samples/llm-function-calling/products" -H "Content-Type: application/json" -H "x-apikey: $APIKEY" | jq
```

---

## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully deployed Apigee proxy that can be configured as a function calling endpoint

You can now go back to the [notebook](https://github.com/GoogleCloudPlatform/apigee-samples/blob/main/llm-function-calling/llm_function_calling.ipynb) to test the sample.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up-llm-function-calling.sh
```
