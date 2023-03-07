# Exposing Apigee to the Internet

---
This sample shows how to expose an Apigee instance to the internet using an [external HTTP(S) load balancer](https://cloud.google.com/load-balancing/docs/https) and [Private Service Connect](https://cloud.google.com/apigee/docs/api-platform/system-administration/northbound-networking-psc).

Let's get started!

---

## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the `exposing-to-internet` directory in the Cloud shell.

```sh
cd exposing-to-internet
```

Set your GCP project ID:

```sh
export PROJECT="<GCP_PROJECT_ID>"
```

Then:

```sh
gcloud config set project $PROJECT
```

---

## Deploy Components

Next, let's create and deploy the resources necessary to expose the Apigee instance via an external load balancer.

```sh
./deploy.sh
```

This script creates a sample [environment and environment group](https://cloud.google.com/apigee/docs/api-platform/fundamentals/environments-overview), plus an [external HTTP(S) load balancer](https://cloud.google.com/load-balancing/docs/https) with a reserved IP address and a [Google managed TLS certificate](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs). The script also tests that the deployment and configuration has been sucessful. Please note the script may take some time to complete while certificate provisioning occurs.


### Test the Apigee instance

Wait a minute for the TLS certificate to be loaded, and then run the following command:
```sh
curl https://$RUNTIME_HOST_ALIAS/healthz/ingress -H 'User-Agent: GoogleHC'
```

You should see an HTTP 200 status returned along with the response body "`Apigee Ingress is healthy`" which indicates the instance is accessible via the external URL.  If you see an SSL error, wait a second and try again.

---
## Conclusion

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Congratulations! You've successfully made your Apigee instance available from the internet.

<walkthrough-inline-feedback></walkthrough-inline-feedback>

## Cleanup

If you want to clean up the artifacts from this example, first source your `env.sh` script, and then run:

```bash
./clean-up.sh
```
