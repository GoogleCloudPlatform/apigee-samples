# Spike Arrest

This sample shows how to protect against traffic spikes and smooth API traffic using Apigee's [SpikeArrest](https://cloud.google.com/apigee/docs/api-platform/reference/policies/spike-arrest-policy) policy.

## About Spike Arrest

The Spike Arrest policy protects against traffic spikes and helps prevent your backend services from being overwhelmed by too many requests. It throttles the number of requests processed by an API proxy, smoothing traffic spikes to protect against performance lags and downtime.

## How it works

Unlike Quota policies that count requests over a longer period of time, Spike Arrest policies protect against sudden spikes in traffic. The policy uses a rate limiting algorithm that smooths the allowed traffic by dividing the rate limit window into smaller time intervals.

For example, if you set the rate to 10 requests per minute (10pm), the Spike Arrest policy will allow:

- One request every 6 seconds (60 seconds / 10 requests)
- This prevents bursts of 10 requests all arriving at once

When the limit is exceeded, subsequent requests are rejected with an error. The rate can be specified per:

- Minute (pm) - e.g., 10pm allows 10 requests per minute
- Second (ps) - e.g., 10ps allows 10 requests per second

## Implementation on Apigee

This sample implements a basic Spike Arrest policy that:

1. Limits requests to 10 per minute (smoothed distribution)
2. Can optionally identify clients using a header
3. Supports message weighting for different request types
4. Returns a custom error message when the limit is exceeded

The proxy includes:
- **SA-SpikeArrest**: The spike arrest policy with rate limiting
- **RF-SpikeArrestError**: Custom error response for rate limit violations
- **AM-SuccessfulResponse**: Success response message

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Access to deploy proxies in Apigee
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=spike-arrest/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the `apigee-samples` repo, and switch to the `spike-arrest` directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/spike-arrest
```

2. Edit `env.sh` and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee API proxy

```bash
./deploy-spike-arrest.sh
```

## Testing the Spike Arrest Proxy

To run the tests, first retrieve Node.js dependencies with:

```bash
npm install
```

Ensure the following environment variable has been set correctly:

* `PROXY_URL`

and then run the tests:

```bash
npm run test
```

## Example Requests

### Successful Request

When requests are within the rate limit:

```bash
curl -v https://$APIGEE_HOST/v1/samples/spike-arrest
```

Expected response:
```json
{
  "status": "success",
  "message": "Request processed successfully",
  "timestamp": "2024-01-08T10:30:00Z"
}
```

### Rate Limited Request

When the rate limit is exceeded, you'll receive:

```bash
for i in {1..15}; do curl -v https://$APIGEE_HOST/v1/samples/spike-arrest; sleep 0.5; done
```

Expected response for requests exceeding the limit:
```json
{
  "error": {
    "code": "429",
    "message": "Spike arrest limit exceeded. Please retry after some time.",
    "status": "RATE_LIMITED"
  }
}
```

### Using Client Identification

You can identify different clients by passing an `api_key` header:

```bash
curl -H "api_key: client-123" https://$APIGEE_HOST/v1/samples/spike-arrest
```

### Using Message Weight

You can assign different weights to requests using the `weight` header:

```bash
curl -H "weight: 2" https://$APIGEE_HOST/v1/samples/spike-arrest
```

A request with weight=2 will count as 2 requests towards the rate limit.

## Understanding the Rate

The spike arrest is configured with a rate of `10pm` (10 per minute). This means:
- Apigee smooths the traffic by allowing 1 request every 6 seconds
- If you send requests faster than this, you'll hit the spike arrest limit
- The policy distributes the allowed requests evenly across the time window

To see the smoothing in action, try sending requests at different intervals:

```bash
# Fast requests - will hit spike arrest
for i in {1..15}; do curl https://$APIGEE_HOST/v1/samples/spike-arrest; done

# Slower requests - within the limit
for i in {1..10}; do curl https://$APIGEE_HOST/v1/samples/spike-arrest; sleep 7; done
```

## Clean up

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run:

```bash
./clean-up-spike-arrest.sh
```

## Key Differences: Spike Arrest vs Quota

| Feature | Spike Arrest | Quota |
|---------|-------------|-------|
| Purpose | Protect against traffic spikes | Enforce business contracts |
| Time Window | Seconds/Minutes (smoothed) | Minutes/Hours/Days/Months |
| Distribution | Evenly distributed | Cumulative count |
| Use Case | Performance protection | Consumption limits |

## Additional Resources

- [Spike Arrest Policy Reference](https://cloud.google.com/apigee/docs/api-platform/reference/policies/spike-arrest-policy)
- [Rate Limiting Best Practices](https://cloud.google.com/apigee/docs/api-platform/develop/rate-limiting)
- [Quota Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/quota-policy)
