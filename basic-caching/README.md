# Basic Caching

This sample shows how to implement caching using Apigee's [ResponseCache](https://cloud.google.com/apigee/docs/api-platform/reference/policies/response-cache-policy), [PopulateCache](https://cloud.google.com/apigee/docs/api-platform/reference/policies/populate-cache-policy), and [LookupCache](https://cloud.google.com/apigee/docs/api-platform/reference/policies/lookup-cache-policy) policies.

## About caching

Using policies for general purpose caching, you can persist any objects your proxy requires across multiple request/response sessions. You can also cache the response of a backend resource with the ResponseCache policy. Response caching is especially helpful when backend data is updated only periodically. The ResponseCache policy can reduce calls to backend data sources.

## How it works

Through the ResponseCache policy, you can also have Apigee look at certain HTTP response caching headers and take actions according to header directives. For example, on responses from backend targets, Apigee supports the Cache-Control header. This header can be used to control the maximum age of a cached response, among other things. For more information, see [Support for HTTP response headers](https://cloud.google.com/apigee/docs/api-platform/cache/http-response-caching).

With the PopulateCache policy, LookupCache policy, and InvalidateCache policy, you can populate, retrieve, and flush cached data at runtime. At runtime, your cache policies copy values between proxy variables and the configured cache you specify. When a value is placed in the cache, it is copied from the variable you specify to the cache. When it is retrieved from the cache, it is copied into the variable for use by your proxy.

For more details refer to [Caching and persistence overview](https://cloud.google.com/apigee/docs/api-platform/cache/persistence-tools), and [Cache internals](https://cloud.google.com/apigee/docs/api-platform/cache/cache-internals).

## Implementation on Apigee

This sample demonstrates how to use the ResponseCache policy to cache the response from the target backend. When the request cannot be served from a cache entry, the current time is also cached, and is returned as the cached-on header. Since this additional data point is not part of the target backend's response payload, caching is achieved by using the PopulateCache, and LookupCache policies.

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

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=basic-quota/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the `apigee-samples` repo, and switch to the `basic-caching` directory

``` bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/basic-caching
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

``` bash
./deploy-basic-caching.sh
```

This will not only deploy the proxy but also run the tests.

## Testing the Quota Proxy

If you would like to run the tests separately from deploying the proxy, first retrieve Node.js dependencies with (this step is not necessary if you already ran the deploy-basic-caching.sh script):

``` bash
npm install
```

Ensure the following environment variables have been set correctly:

* `PROXY_URL`

``` bash
export PROXY_URL="$APIGEE_HOST/v1/samples/basic-caching"
```

and then run the tests:

``` bash
npm run test
```

## Example Requests

To manually test the proxy, you can make requests directly to the API with your tool of choice.

The requests can be made like this:

``` bash
curl -S "https://$APIGEE_HOST/v1/samples/basic-caching?q=apigee&country=us"
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, ensure the `PROJECT`, `APIGEE_HOST`, and `APIGEE_ENV` environment variabales have been set as described in [Setup Instructions](#setup-instructions), and then run the following command.

``` bash
./clean-up-basic-caching.sh
```
