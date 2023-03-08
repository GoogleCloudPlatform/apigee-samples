# Exposing Apigee Instances to the Internet

This sample shows how to expose an Apigee instance to the internet using a [Google Cloud external HTTP(S) Load Balancer](https://cloud.google.com/load-balancing/docs/https) and [Private Service Connect](https://cloud.google.com/apigee/docs/api-platform/system-administration/northbound-networking-psc).

## How it works

With Apigee X, customers have full control over whether or not to expose their [runtime](https://cloud.google.com/apigee/docs/api-platform/get-started/what-apigee#componentsofapigeeedge-edgeapiservices) instances externally. Apigee X instances are not exposed to the internet by default, however customers may choose to serve traffic to external API consumers by placing an external HTTP(S) load balancer in front of Apigee. Customers may then leverage other features of Google Cloud Load Balancing such as [Cloud Armor](https://cloud.google.com/armor) WAF & DDoS protection for additional security in front of their APIs.

When following the Apigee X [provisioning wizard](https://cloud.google.com/apigee/docs/api-platform/get-started/wizard-select-project), you will be prompted to [configure access routing](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing) for your newly created instance. If you choose the internal option, the instance is only accessible internally via your GCP VPC network. If you subsequently decide you wish to expose it externally, this sample shows how to add the load balancer. The sample creates a sample environment and environment group, then reserves a static IP address and creates a load balancer with a [Google managed TLS certificate](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs) and an external hostname using [nip.io](https://nip.io/) to resolve to the IP.

## Northbound Routing With Private Service Connect (PSC)

This sample makes use of GCP's [Private Service Connect](https://cloud.google.com/vpc/docs/private-service-connect) (aka PSC) capability to connect an external load balancer to the Apigee X instance.  Apigee supports PSC for both [northbound](https://cloud.google.com/apigee/docs/api-platform/system-administration/northbound-networking-psc) (ingress) and [southbound](https://cloud.google.com/apigee/docs/api-platform/architecture/southbound-networking-patterns-endpoints) (egress) connectivity.  This sample only deals with use of PSC for northbound connections from the internet.

Each Apigee X instance contains a PSC [Service Attachment](https://cloud.google.com/vpc/docs/about-vpc-hosted-services#service-attachments). Information about the attachment can be found on the [Instances](https://cloud.google.com/apigee/docs/api-platform/system-administration/instances) page in the Apigee management UI, or via the [`organizations.instances.get`](https://cloud.google.com/apigee/docs/reference/apis/apigee/rest/v1/organizations.instances/get) API method.

Customers can connect an external load balancer to this attachment using a [PSC network endpoint group](https://cloud.google.com/load-balancing/docs/negs#psc-neg), or PSC NEG for short.  PSC provides a fully managed option to establish connectivity, which does not involve the use of network bridge VMs.   The high level architecture is depicted in the diagram below:

![Architecture](https://cloud.google.com/static/apigee/docs/api-platform/images/psc-arch.png)

## Prerequisites
1. An Apigee X instance already provisioned. If not, you may follow the steps [here](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro).
2. Your account must have [permissions to configure access routing](https://cloud.google.com/apigee/docs/api-platform/get-started/permissions#access-routing-permissions) and create Apigee environment and environment groups. See the predefined roles listed [here](https://cloud.google.com/apigee/docs/api-platform/get-started/permissions#predefined-roles).
2. Make sure the following tools are available in your terminal's `$PATH` (Cloud Shell has these preconfigured)
    * [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    * curl
    * jq
    * npm

# (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=exposing-to-internet/docs/cloudshell-tutorial.md)

## Setup instructions

1. Clone the `apigee-samples` repo, and switch the `exposing-to-internet` directory

```bash
git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
cd exposing-to-internet
```

2. Edit `env.sh` and configure the following variables:

* `PROJECT` the project where your Apigee organization is located
* `NETWORK` the VPC network where the PSC NEG will be deployed
* `SUBNET` the VPC subnet where the PSC NEG will be deployed

Now source the `env.sh` file
```bash
source ./env.sh
```

3. Deploy the environment, environment group and load balancing components:

```bash
./deploy.sh
```
Please note the script may take some time to complete while certificate provisioning occurs.

## Testing
To run the tests, first retrieve Node.js dependencies with:
```
npm install
```
Ensure the following environment variables have been set correctly:
* `RUNTIME_HOST_ALIAS`

and then run the tests:
```
npm run test
```

## Example Requests
To manually test the instance via the external load balancer URL, wait a minute and then make the following request:
```
curl https://$RUNTIME_HOST_ALIAS/healthz/ingress -H 'User-Agent: GoogleHC'
```

You should see an HTTP 200 status returned along with the response body "`Apigee Ingress is healthy`" which indicates the instance is accessible via the external URL. If you see an SSL error, wait a second and try again.

## Cleanup

If you want to clean up the artifacts from this example, first source your `env.sh` script, and then run

```bash
./clean-up.sh
```