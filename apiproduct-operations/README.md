# API Product Operations

This sample shows how API Product Operations work in Apigee; specifically, how
verifying credentials can check whether a particular verb/path combination
should be permitted for a calling application, based on the configuration of
allowed Operations in an API Product.

## About API Products

In Apigee, the [API Product](https://cloud.google.com/apigee/docs/api-platform/publish/what-api-product)
is the unit of packaging for APIs.
- it allows an API Publisher to share an API out, via an API Catalog, or developer portal.
- it is the thing an API Consumer Developer gains access to, via the self-service API Catalog

Each API Product has a set of configuration data that can be used at runtime.
This might be data that allows the API Proxy to behave differently, depending on
the product that is being used to expose it. Gold, Silver, and Bronze products
might each have a different rate limit, for example. Or different pricing
levels. Or different target systems. Information about which data fields to include or
exclude from a response. OAuth scopes. It's a very flexible model.

### The Operations within an API Product

One particular aspect of an API Product is the set of Operations it allows.

API Products can group subsets of the operations available in one or more API
proxies, into a consumable unit. Let's look at an example. Suppose an API Proxy
fronts a contract management system. The designers of the API might use these
REST-ful Verb + Path combinations to support the use cases:

|  # | use case                                             | verb + path       |
| -- | ---------------------------------------------------- | ----------------- |
|  1 | review the list of signed or unsigned contracts      | `GET /contracts`    |
|  2 | review the detail of a single contract               | `GET /contracts/*`  |
|  3 | add a new contract into the system                   | `POST /contracts`   |
|  4 | update an unsigned contract with a signature         | `POST /contracts/*` |

The API Publisher might not want to grant authorization to ALL of the API to
each distinct application that uses it.  The publisher might create 3 different
API Products, with different purposes:

| product | purpose                                                                            |
| ------- | ---------------------------------------------------------------------------------- |
| viewer  | allow the app to list existing contracts, and view specifics of existing contracts |
| creator | allow the app to initiate a new contract, without viewing existing contracts       |
| admin   | allow administration of the contracts management system. Any operation is allowed  |

To make this happen, in Apigee each API Product specifies a set of operations on
the API Proxies it authorizes.  In this example, the products would get these
operations

| product | operations                                                                   |
| ------- | ---------------------------------------------------------------------------- |
| viewer  | `GET /contracts`, `GET /contracts/*`                                         |
| creator | `POST /contracts`                                                            |
| admin   | `GET /contracts`, `GET /contracts/*`, `POST /contracts`, `POST /contracts/*` |


## Credentials are "the key" for checking the Operation

Configuring the set of API Products with the various operations is one part of
the set up.  The next step is to grant access to these products to different
applications - this is done via app credentials. In Apigee, you need to
configure an App authorized for the product, to get a set of credentials.  This
is typically done in the self-service developer portal (aka API Catalog). After
obtaining credentials, the developer embeds the credentials into the app, and
sends those credentials along with API requests.

When the API request reaches Apigee, the API proxy that handles it must invoke a
policy to verify the credentials - either
[VerifyAPIKey](https://cloud.google.com/apigee/docs/api-platform/reference/policies/verify-api-key-policy)
or
[OAuthV2/VerifyAccessToken](https://cloud.google.com/apigee/docs/api-platform/reference/policies/oauthv2-policy#verifyaccesstoken). When
that happens, Apigee checks the credential and maps it to one or more API
Products. (In the simple case, an app is authorized for a single API Product,
but Apigee allows apps to have access to more than one product.)  Then, Apigee
checks that the current executing operation - using the REST model, this is a
verb+path combination - is included within one of the API Products that is
authorized for that credential. If not, then the request is rejected.

In our example, for a `GET /contracts` request, the credential must be authorized
for the viewer or admin product. For a `POST /contracts` request, the credential
must be authorized for either creator or admin.

## Implementation in the API Proxy

This sample uses a simple API Proxy to demonstrate this function. The proxy uses
a
[VerifyAPIKey](https://cloud.google.com/apigee/docs/api-platform/reference/policies/verify-api-key-policy)
policy to identify the calling application and the API product associated with
the proxy. All of the magic of authorizing the operation for the given
credential is done _implicitly_ by the VerifyAPIKey policy. There's nothing else
you need to do in the API Proxy to make that happen.

For the purposes of demonstration, the proxy uses an
[AssignMessage](https://cloud.google.com/apigee/docs/api-platform/reference/policies/assign-message-policy)
policy to set a mock success response, which includes the API product name, and
the operation that was authorized.

There's also a conditional flow in the proxy that uses [OAuthV2/VerifyAccessToken](https://cloud.google.com/apigee/docs/api-platform/reference/policies/oauthv2-policy#verifyaccesstoken) in place of VerifyAPIKey.
The behavior with regard to operations authorization checks is exactly the same.


## Screencast

[![screencast link](https://img.youtube.com/vi/to-be-determined/0.jpg)](https://www.youtube.com/watch?v=to-be-determined)

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Permissions to create and deploy proxies, to create products, and to register apps and developers in Apigee. Get these permissions via the Apigee orgadmin role, or the combination of two roles: API Admin and Developer Admin. ([more on Apigee-specific roles](https://cloud.google.com/apigee/docs/api-platform/system-administration/apigee-roles#apigee-specific-roles))
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * unzip
    * curl
    * jq
    * npm

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=apiproduct-operations/docs/cloudshell-tutorial.md)

## Manual Setup instructions

If you've clicked the blue button above, you can ignore the rest of this README.
If you choose _not_ to follow the tutorial in Cloud Shell, you can follow these steps on your own:

1. Clone the `apigee-samples` repo, and cd into the `apiproduct-operations` directory

   ```bash
   git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
   cd apiproduct-operations
   ```

2. Edit `env.sh` and configure the following variables:

   * `PROJECT` the project where your Apigee organization is located
   * `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
   * `APIGEE_ENV` the Apigee environment where the demo resources should be created

   Now source the `env.sh` file

   ```bash
   source ./env.sh
   ```

3. Configure the API proxies, products and apps into your Apigee organization

   ```bash
   ./setup-apiproduct-operations.sh
   ```

   This step will also run some tests to verify the setup.
   It will then print some information about the credentials it has provisioned.


### Running the automated tests

Ensure the required environment variables have been set correctly. The setup
script will provide easy cut/paste instructions regarding the variables and the values to set.

And then use `npm` to run the tests:
```bash
npm run test
```

### Manually send requests

To manually test the proxy, make requests using the API keys created by the setup script.

After successful setup, you will see three products (`apiproduct-operations-{viewer,creator,admin}`) and three
corresponding apps  (`apiproduct-operations-{viewer,creator,admin}-app`). Instructions for how to find
application credentials can be found [here](https://cloud.google.com/apigee/docs/api-platform/publish/creating-apps-surface-your-api#view-api-key).

Invoke your first request using the viewer credential:
```bash
curl -i -X GET https://${APIGEE_HOST}/v1/samples/apiproduct-operations/apikey/users -H APIKEY:$VIEWER_CLIENT_ID"
```

Because the viewer credential is authorized on the viewer Product, which allows
the `GET /*/users` operation, you should see a success response.

Now try the creator credential on the same request
```bash
curl -i -X GET https://${APIGEE_HOST}/v1/samples/apiproduct-operations/apikey/users -H APIKEY:$CREATOR_CLIENT_ID"
```

You should see a rejection; the creator product does not allow the `GET /*/users` operation.

Many more combinations of credential and operation are possible. See the Cloud Shell tutorial for full details.

### Cleanup

To remove the configuration from this example in your Apigee Organization, first
source your `env.sh` script, and then, in your shell, run:

```bash
./clean-apiproduct-operations.sh
```
