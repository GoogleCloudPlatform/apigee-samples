# Property Set

This sample shows how to easily define a Property Set and how to
access data from it.
This sample leverages the following policy:

* [Assign Message](https://cloud.google.com/apigee/docs/api-platform/reference/policies/assign-message-policy?hl=en) policy to set the JSON response with values retrieved from a [property set](https://cloud.google.com/apigee/docs/api-platform/cache/property-sets)
* [JavaScript](https://cloud.google.com/apigee/docs/api-platform/reference/policies/javascript-policy?hl=en) policy to set HTTP response headers with values
retrieved from the same property set

## About Property Set

A property set is a custom collection of key/value pairs that store data.
API proxies can retrieve this data when they execute.

Typically, you use property sets to store non-expiring data that shouldn't
be hard-coded in your API proxy logic. You can access property set data
anywhere in a proxy where you can access flow variables.

A common use case for property sets is to provide values that are
associated with one environment or another. For example, you can create
an environment-scoped property set with configuration values that are
specific to proxies running in your test environment, and another set for
your production environment.

## How it works

Typically, you store property set values as name/value pairs in a file.
Property set files are resource files of type properties.

Property set files support the same syntax as Java properties files;
for example, they can contain Unicode values and can use # or !
characters as comment markers.

You must add the suffix .properties to a property file name. For example:
```myconfig.my_key.properties``` is allowed, but ```myconfig.my_key```
is not allowed.

The structure of a property set specification is: ```property_set_name.property_name.properties```

The following example (used in this sample) shows a simple property
set (```myProps.properties```)
file that defines several properties:

```
# myProps.properties file
# General properties
foo=bar
baz=biff

# Messages/notes/warnings
message=This is a basic message.
note_message=This is an important message.
error_message=This is an error message.

# Keys
publickey=abc123
privatekey=splitwithsoundman
```

## Implementation on Apigee

This sample is configured as a "no target API Proxy".

A Property Set (```myProps.properties```) is part of the ```property-set```
API Proxy resources.

We use the [Assign Message](https://cloud.google.com/apigee/docs/api-platform/reference/policies/assign-message-policy?hl=en)
policy to get values for two keys of the Property Set.
This same policy is used to set a response presenting some key/value pairs
in the form of a JSON content.

We use the [JavaScript](https://cloud.google.com/apigee/docs/api-platform/reference/policies/javascript-policy?hl=en)
policy to get values for two keys of the Property Set.
This same policy is used to set HTTP response headers using the accessed values.

## Screencast



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

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=property-set/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the `apigee-samples` repo, and switch the `property-set` directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd apigee-samples/property-set
```

2. Edit `env.sh` and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV
* `APIGEE_ENV` the Apigee environment where the demo resources should be created

Now source the `env.sh` file

```bash
source ./env.sh
```

3. Deploy Apigee API proxies:

```bash
./deploy.sh
```

## Example Requests

To manually test the proxy, make requests using curl:

```bash
curl -v https://$APIGEE_HOST/v1/samples/property-set
```

## Cleanup

If you want to clean up the artifacts from this example in your Apigee Organization, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```
