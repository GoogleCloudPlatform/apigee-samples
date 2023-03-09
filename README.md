# Apigee Samples

* [Intro](#intro)
* [Audience](#who)
* [Before you begin](#before)
* [Using the sample proxies](#using)
* [Samples](#samples)
* [Modifying a sample proxy](#modifying)
* [Ask questions on the Apigee Community](#ask)
* [Apigee documentation](#docs)
* [Contributing](#contributing)

---

## <a name="intro"></a>Intro

This repository contains a collection of sample API proxies that you can deploy and run on Apigee X or [hybrid](https://cloud.google.com/apigee/docs/hybrid/v1.8/what-is-hybrid).

The samples provide a jump-start for developers who wish to design and create Apigee API proxies.

### <a name="who"></a>Audience

You are an [Apigee](https://cloud.google.com/apigee) API proxy developer, or you would like to learn about developing APIs that run on Apigee X & hybrid. At a minimum, we assume you're familiar with Apigee and how to create simple API proxies. To learn more, we recommend this [getting started tutorial](https://cloud.google.com/apigee/docs/api-platform/get-started/get-started).

## <a name="before"></a>Before you begin

1. See the full list of [Prerequisites](https://cloud.google.com/apigee/docs/api-platform/get-started/prerequisites) for installing Apigee.

2. You'll need access to a Google Cloud Platform account and project. [Sign up for a free GCP trial account.](https://console.cloud.google.com/freetrial)

3. If you don't have one, you'll need to provision an Apigee instance. [Create a free Apigee eval instance.](https://apigee.google.com/setup/eval)

4. Clone this project from GitHub to your system.

## <a name="using"></a>Using the sample proxies

Most developers begin by identifying an interesting sample based on a specific use case or need. You'll find all the samples in the root folder.

### <a name="samples"></a>Samples
- [deploy-apigee-proxy](deploy-apigee-proxy) -
  Deploy Apigee proxy using Apigee Maven plugin and Cloud Build
- [deploy-apigee-sharedflow](deploy-apigee-sharedflow) -
  Deploy Apigee sharedflow using Apigee Maven plugin and Cloud Build
- [deploy-apigee-config](deploy-apigee-config) -
  Deploy Apigee configurations using Apigee Maven plugin and Cloud Build
- [authorize-idp-access-tokens](authorize-idp-access-tokens) - 
  Authorize JWT access tokens issued by an Identity Provider  
- [oauth-client-credentials](oauth-client-credentials) -
  A sample proxy which uses the OAuth 2.0 client credentials grant type flow
- [oauth-client-credentials-with-scope](oauth-client-credentials-with-scope) -
  A sample proxy which uses the OAuth 2.0 client credentials grant type flow and limit access using [OAuth2 scopes](https://cloud.google.com/apigee/docs/api-platform/security/oauth/working-scopes)
- [cloud-logging](cloud-logging) -
  A sample proxy that logs custom messages to Google Cloud Logging
- [basic-quota](basic-quota) -
  A sample which shows how to implement a basic API consumption quota
- [cloud-run](cloud-run) -
  A sample proxy to invoke Cloud Run Service from Apigee
- [integrated-developer-portal](integrated-developer-portal) -
  This sample demonstrates how to create an Apigee Integrated portal and shows how to expose your API products to its catalog
- [exposing-to-internet](exposing-to-internet) -
  This sample demonstrates how to expose an Apigee instance to the internet using a Google Cloud external HTTP(S) Load Balancer

You can find videos of all the samples in this [YouTube playlist](https://goo.gle/ApigeeAcceleratorSeries)

### <a name="modifying"></a>Modifying a sample proxy

Feel free to modify and build upon the sample proxies. You can make changes in the Apigee [management UI](https://cloud.google.com/apigee/docs/api-platform/develop/ui-edit-proxy) or by using our Cloud Code [extension for local development](https://cloud.google.com/apigee/docs/api-platform/local-development/setup) in Visual Studio Code. Whichever approach is comfortable for you.

Simply redeploy the proxies for changes to take effect.

## <a name="ask"></a>Ask questions on the Apigee Community

[Apigee Community](https://www.googlecloudcommunity.com/gc/Apigee/bd-p/cloud-apigee) is a great place to ask questions and find answers about developing API proxies.

## <a name="docs"></a>Apigee documentation

The Apigee docs are located [here](https://cloud.google.com/apigee/docs).

## <a name="contributing"></a>Contributing

New samples should be added as a root level directory in this repository.

For more details on how to contribute please see the [guidelines](./CONTRIBUTING.md).

## License

All solutions within this repository are provided under the
[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) license.
Please see the [LICENSE](./LICENSE.txt) file for more detailed terms and conditions.

## Not Google Product Clause

This is not an officially supported Google product, nor is it part of an
official Google product.

## Support

If you need support or assistance, you can try inquiring on [Google Cloud Community
forum dedicated to Apigee](https://www.googlecloudcommunity.com/gc/Apigee/bd-p/cloud-apigee).
