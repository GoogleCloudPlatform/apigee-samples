# Auto Insurance Agent

A virtual assistant for auto insurance that uses API hub to provide APIs as tools.

## Pre-Requisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. [Provision Apigee API hub](https://cloud.google.com/apigee/docs/apihub/provision)
3. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
4. Enable Vertex AI in your project
5. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
    - [gcloud SDK](https://cloud.google.com/sdk/docs/install)
    - [apigeecli](https://github.com/apigee/apigeecli)
    - unzip
    - curl
    - jq


## Setup environment

Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

Navigate to the 'adk-auto-insurance-agent' directory in the Cloud shell.

```sh
cd adk-auto-insurance-agent
```

Edit the provided sample `env.sh` file, and set the environment variables there.

Then, source the `env.sh` file in the Cloud shell.

```sh
source ./env.sh
```

## Deploy Apigee configurations

Next, let's deploy the sample to Apigee. Just run

```bash
./deploy-adk-auto-insurance-agent.sh
```

Export the `APIKEY` variable as mentioned in the command output

## Verification

You can test the sample with the following curl commands:

### To access Rewards API

#### List Rewards:

```sh
curl --location "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/rewards" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY"
```

### To access Claims API

#### Get Claim:

```sh
curl --location "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/claims/31432" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY"
```

#### List Claims:

```sh
curl --location "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/claims" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY"
```

#### Create Claim:

```sh
curl --location "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/claims" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY" \
--data '{"description": "Hail storm","location": "Mountain View, CA","memberId": "12345","reason": "HAIL_DAMAGE","vehicle": "Toyota Camry"}'
```

#### Delete Claim:

```sh
curl --location --request DELETE "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/claims/12345" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY"
```

### To access Members API

#### Get Member:

```sh
curl --location "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/members/31432" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY"
```

#### List Members:

```sh
curl --location "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/members" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY"
```

#### Create Member:

```sh
curl --location "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/members" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY" \
--data '{"firstName": "John","lastName": "Doe","email": "john.doe@example.com","phoneNumber": "555-123-4567","address": "123 Highland Dr","city": "Some Creek","state": "GA","zip": "30303"}'
```

#### Delete Member:

```sh
curl --location --request DELETE "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/members/12345" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY"
```

### To access Roadside Assistance API

#### Get Tow:

```sh
curl --location "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/tows/31432" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY"
```

#### List Tows:

```sh
curl --location "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/tows" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY"
```

#### Create Tow:

```sh
curl --location "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/tows" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY" \
--data '{"memberId": "12345","location": "Mountain View, CA"}'
```

#### Delete Tow:

```sh
curl --location --request DELETE "https://$APIGEE_HOST/v1/samples/adk-cymbal-auto/tows/45345" \
--header "Content-Type: application/json" \
--header "x-apikey: $APIKEY"
```