# CORS Security

---
This sample lets you create an API that is protected against cross-origin-requests (CORS)

Let's get started!

---

## Setup instructions

1. Clone the apigee-samples repo, and switch to the cors directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/cors
```

2. Edit the `env.sh` and configure the ENV vars

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```
---

## Deploy Apigee components

Next, let's deploy some CORS protected Apigee sample proxy

```bash
./deploy-cors.sh
```

---

## Test CORS Proxy

Now that our API proxy is deployed, let's enable the debugger so we can see requests as they come through:
1. Click into the sample-cors proxy
2. Navigate to the debug section
3. Choose to start a debug session for the currently deployed proxy version

With the proxy debugger still running, call the sample CORS proxy from a cross origin client:
1. Navigate to an online HTTP request sending service such as https://cors-tester.org. The requests need to be sent from an online service and should not be sent from your local machine.
2. From https://cors-tester.org enter your proxy's URL, https://\[APIGEE_HOST\]/v1/sample/cors into the URL input box. Leave all other fields at their default values
3. Click send and view the response. You should see 200 response, meaning our CORS policy is working as expected and our test was a success!
4. Navigate to the Apigee debugger. OPTIONS? SUCCESS?

Start Apigee Debugger > Go to cors-tester.org > Enter in the information > test

Should retun 200 response message > If this wasn't CORS protected the request would fail

Further notes on implmentation:
1. Can restrict domains
2. Can restrict headers and other pieces of information
3. Learn more about the CORS policy here

---
## Conclusion & Cleanup

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully created a CORS secured Apigee API.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

To clean up the artifacts created source your `env.sh` script and run the following to delete your sample CORS proxy:

```bash
./clean-up-cors.sh
```