# CORS Security

---
This sample lets you create an API that uses the cross-origin resource sharing (CORS) mechanism to allow requests from external webpages and applications

Let's get started!

---

## Setup instructions

1. Navigate to the 'cors' directory in the Cloud Shell.

```sh
cd cors
```

2. Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

3. Edit the `env.sh` and configure the ENV vars. Click <walkthrough-editor-open-file filePath="cors/env.sh">here</walkthrough-editor-open-file> to open the file in the editor

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

## Deploy Apigee components

Next, let's deploy some CORS protected Apigee sample proxy

```bash
./deploy-cors.sh
```

---

## Test CORS Proxy

Now that our API proxy is deployed, let's enable the debugger so we can see requests as they come through:
1. Navigate to the [Apigee homepage](https://apigee.google.com). Go to Develop > API Proxies and click into the sample-cors proxy
2. Navigate to the debug tab
3. Choose to start a debug session for the currently deployed proxy version

With the proxy debugger still running, call the sample CORS proxy from a cross-origin client:
1. Navigate to an online HTTP request service such as https://test-cors.org. The requests need to be sent from an online web service and should not be sent from your local machine.
2. From https://test-cors.org find the Remote URL field and enter in your proxy's URL, https://\[APIGEE_HOST\]/v1/samples/cors. Leave all other fields at their default values
3. Click the Send Request button and view the response. You should see 200 response, meaning our CORS policy is working as expected and our test was a success!
4. Navigate to the Apigee debugger. You should see a 200 response there as well!

### Further Notes on CORS
Apigee's CORS policy can do much more than open up your APIs for cross-origin traffic like we did in this sample. It is important to understand how it can be used to protect your APIs from unwanted traffic and attacks. Please read the policy documentation to understand concepts like [allowed origins](https://cloud.google.com/apigee/docs/api-platform/reference/policies/cors-policy#allow-origins) and [maximum  age](https://cloud.google.com/apigee/docs/api-platform/reference/policies/cors-policy#max-age)

---
## Conclusion & Cleanup

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully created a CORS secured Apigee API.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

To clean up the artifacts created source your `env.sh` script and run the following to delete your sample CORS proxy:

```bash
./clean-up-cors.sh
```