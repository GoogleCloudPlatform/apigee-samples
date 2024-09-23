# Apigee Samples

- [Apigee Samples](#apigee-samples)
  - [Intro](#intro)
    - [Audience](#audience)
  - [Before you begin](#before-you-begin)
  - [Using the sample proxies](#using-the-sample-proxies)
    - [Samples](#samples)
    - [Modifying a sample proxy](#modifying-a-sample-proxy)
  - [Ask questions on the Community Forum](#ask-questions-on-the-community-forum)
  - [Apigee documentation](#apigee-documentation)
  - [Contributing](#contributing)
  - [License](#license)
  - [Not Google Product Clause](#not-google-product-clause)
  - [Support](#support)

---

## <a name="intro"></a>Intro

This repository contains a collection of sample API proxies that you can deploy and run on Apigee X or [hybrid](https://cloud.google.com/apigee/docs/hybrid/latest/what-is-hybrid).

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

|    | Sample                      | Description                                                            | Cloud Shell Tutorial |
|-----|-----------------------------|------------------------------------------------------------------------|----------------------|
|1| [deploy-apigee-proxy](deploy-apigee-proxy)         | Deploy Apigee proxy using Apigee Maven plugin and Cloud Build          | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=deploy-apigee-proxy/docs/cloudshell-tutorial-maven.md)                     |
|2| [deploy-apigee-sharedflow](deploy-apigee-sharedflow)   | Deploy Apigee sharedflow using Apigee Maven plugin and Cloud Build     | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=deploy-apigee-sharedflow/docs/cloudshell-tutorial-maven.md)                     |
|3| [deploy-apigee-config](deploy-apigee-config)        | Deploy Apigee configurations using Apigee Maven plugin and Cloud Build | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=deploy-apigee-config/docs/cloudshell-tutorial-maven.md)                     |
|4| [authorize-idp-access-tokens](authorize-idp-access-tokens) | Authorize JWT access tokens issued by an Identity Provider             | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=authorize-idp-access-tokens/docs/cloudshell-tutorial.md)                     |
|5| [oauth-client-credentials](oauth-client-credentials) | A sample proxy which uses the OAuth 2.0 client credentials grant type flow             | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=oauth-client-credentials/docs/cloudshell-tutorial.md)                     |
|6| [oauth-client-credentials-with-scope](oauth-client-credentials-with-scope) | A sample proxy which uses the OAuth 2.0 client credentials grant type flow and limit access using [OAuth2 scopes](https://cloud.google.com/apigee/docs/api-platform/security/oauth/working-scopes) | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=oauth-client-credentials-with-scope/docs/cloudshell-tutorial.md)                     |
|7| [cloud-logging](cloud-logging) | A sample proxy that logs custom messages to Google Cloud Logging | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=cloud-logging/docs/cloudshell-tutorial.md) |
|8| [basic-caching](basic-caching) | An example showing how to cache responses and other data using Apigee's built in policies | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=basic-caching/docs/cloudshell-tutorial.md) |
|9| [basic-quota](basic-quota) | A sample which shows how to implement a basic API consumption quota | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=basic-quota/docs/cloudshell-tutorial.md) |
|10| [apiproduct-operations](apiproduct-operations) | Shows the behavior of API Product Operations | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=apiproduct-operations/docs/cloudshell-tutorial.md) |
|11| [cloud-run](cloud-run) | A sample proxy to invoke Cloud Run Service from Apigee | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=cloud-run/docs/cloudshell-tutorial.md) |
|12| [integrated-developer-portal](integrated-developer-portal) | This sample demonstrates how to create an Apigee Integrated portal and shows how to expose your API products to its catalog | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=integrated-developer-portal/docs/cloudshell-tutorial.md) |
|13| [drupal-developer-portal](drupal-developer-portal) | This sample demonstrates how to create a Drupal developer portal using the GCP Marketplace and shows how to expose your Apigee API products to its catalog | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=drupal-developer-portal/docs/cloudshell-tutorial.md) |
|14| [exposing-to-internet](exposing-to-internet) | This sample demonstrates how to expose an Apigee instance to the internet using a Google Cloud external HTTP(S) Load Balancer | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=exposing-to-internet/docs/cloudshell-tutorial.md) |
|15| [json-web-tokens](json-web-tokens) | This sample demonstrates how to generate and verify JSON Web Tokens using the out of the box Apigee JWT policies | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=json-web-tokens/docs/cloudshell-tutorial.md) |
|16| [cors](cors)         | This sample lets you create an API that uses the cross-origin resource sharing (CORS) mechanism to allow requests from external webpages and applications          | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=cors/docs/cloudshell-tutorial.md) |
|17| [extract-variables](extract-variables) | This sample demonstrates how to extract variables and set headers using the out of the box Apigee AssignMessage and ExtractVariable policies | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=extract-variables/docs/cloudshell-tutorial.md) |
|18| [websockets](websockets) | This sample shows how to deploy a sample websockets echo server in Cloud Run and how to use Apigee to expose that service to developers securely | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=websockets/docs/cloudshell-tutorial.md) |
|19| [grpc](grpc) | This sample shows how to deploy a sample gRPC Hello World application in Cloud Run and how to use Apigee to expose that service to developers securely | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=grpc/docs/cloudshell-tutorial.md) |
|20| [mtls-northbound](mtls-northbound) | This sample shows how to configure mTLS using a GCP Private CA (Certificate Authority) on an existing GLB (global load balancer). | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=mtls-northbound/docs/cloudshell-tutorial.md) |
|21| [property-set](property-set) | This sample lets you create an API that uses a property set and shows how to get data from it using a mediation policy (AssignMessage). | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=property-set/docs/cloudshell-tutorial.md) |
|22| [data-deidentification](data-deidentification) | Invokes the Data Loss Prevention (DLP) API to perform data masking (de-identification) on JSON and XML payloads. | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=data-deidentification/docs/cloudshell-tutorial.md) |
|23| [publish-to-apigee-portal](publish-to-apigee-portal) | Publish OpenAPI Spec to Apigee Integrated Portal using Maven plugin and Cloud Build | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=publish-to-apigee-portal/docs/cloudshell-tutorial.md) |
|24| [threat-protection](threat-protection) | Threat Protection sample in Apigee | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=threat-protection/docs/cloudshell-tutorial.md) |
|25| [composite-api](composite-api) | Composite API sample in Apigee | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=composite-api/docs/cloudshell-tutorial.md) |
|26| [cloud-functions](cloud-functions) | A sample proxy that connects to an app running in Cloud Functions | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=cloud-functions/docs/cloudshell-tutorial.md) |
|27| [grpc-web](grpc-web) | A sample proxy that connects to a gRPC-Web service running in Cloud Run | [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=grpc-web/docs/cloudshell-tutorial.md) |

You can find video walkthroughs of many of these samples in this [YouTube playlist](https://goo.gle/ApigeeAcceleratorSeries)

## Samples for LLM Serving with Apigee

The rise of Large Language Models (LLMs) presents an unparalleled opportunity for AI productization, but also necessitates a robust platform to manage, scale, secure, and govern acess to them. While specialized tools and platforms are emerging, organizations can leverage their existing investment in a best-in-class API Management platform like Apigee to effectively handle all their LLM serving needs.

Apigee X plays a crucial role in LLM serving by acting as an intermediary between clients and the LLM endpoints. It provides a secure, reliable, and scalable way to expose LLMs as APIs while offering essential features like:

* **Security:** Authentication, authorization, rate limiting, and protection against attacks.
* **Reliability:** Load balancing, circuit breaking, and failover mechanisms.
* **Performance:** Caching, request/response transformation, and optimized routing.
* **Observability:** Logging, monitoring, and tracing for troubleshooting and analysis.
* **Governance:** API lifecycle management, versioning, and productization.

This repository explores common LLM serving patterns using Apigee X as a robust and feature-rich API maanagement platform. While the primary focus is on serving Gemini models, the principles and patterns discussed here can be adapted for other LLMs.

|    | Sample                      | Description                                                            | Open Notebook |
|-----|-----------------------------|------------------------------------------------------------------------|----------------------|
|1| [llm-token-limits](llm-token-limits) | Apigee's API Products provide real-time monitoring and enforcement of token usage limits for LLMs, enabling effective management of token consumption across different providers and consumers. | [![notebook](https://cloud.google.com/ml-engine/images/colab-logo-32px.png)](./llm-token-limits/llm_token_limits.ipynb) |
|2| [llm-semantic-cache](llm-semantic-cache) | This sample performs a cache lookup of responses on Apigee's Cache layer and Vector Search as an embeddings database. | [![notebook](https://cloud.google.com/ml-engine/images/colab-logo-32px.png)](./llm-semantic-cache/llm_semantic_cache_v1.ipynb) |
|3| [llm-circuit-breaking](llm-circuit-breaking) | Apigee enhances the resilience and prevents outages in Retrieval Augmented Generation applications that utilize multiple Large Language Models by intelligently managing traffic and implementing circuit breaking to avoid exceeding endpoint quotas. |  [![notebook](https://cloud.google.com/ml-engine/images/colab-logo-32px.png)](./llm-circuit-breaking/llm_circuit_breaking.ipynb) |
|4| [llm-logging](llm-logging) | Logging prompts and responses of large language models facilitates performance analysis, security monitoring, and bias detection, ultimately enabling model improvement and risk mitigation. |  [![notebook](https://cloud.google.com/ml-engine/images/colab-logo-32px.png)](./llm-logging/llm_logging_v1.ipynb) |

### <a name="modifying"></a>Modifying a sample proxy

Feel free to modify and build upon the sample proxies. You can make changes in the Apigee [management UI](https://cloud.google.com/apigee/docs/api-platform/develop/ui-edit-proxy) or by using our Cloud Code [extension for local development](https://cloud.google.com/apigee/docs/api-platform/local-development/setup) in Visual Studio Code. Whichever approach is comfortable for you.

Simply redeploy the proxies for changes to take effect.

## <a name="ask"></a>Ask questions on the Community Forum

[The Apigee Forum](https://www.googlecloudcommunity.com/gc/Apigee/bd-p/cloud-apigee) on the [Google Cloud Community site](https://www.googlecloudcommunity.com/) is a great place to ask questions and find answers about developing API proxies.

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
