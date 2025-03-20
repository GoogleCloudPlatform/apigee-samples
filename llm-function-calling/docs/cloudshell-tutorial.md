# llm-function-calling

---

This is a sample on how to deploy a sample Apigee proxy and configure it as a [function calling](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/function-calling). 

[Function Calling in Gemini](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/function-calling) lets developers create a description of a function in their code, then pass that description to a language model in a request. The response from the model includes the name of a function that matches the description and the arguments to call it with. This feature makes it easier for developers to get structured data outputs from generative models.

![architecture](./images/arch.png)

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

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

## Deploy Apigee configurations

Next, let's deploy the sample to Apigee. Just run

```bash
./deploy-llm-function-calling.sh
```
---

## Verification

Run this curl command

```sh
curl --location "https://$APIGEE_HOST/v1/samples/llm-function-calling/products" -H "Content-Type: application/json" -H "x-apikey: $APIKEY" 
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
