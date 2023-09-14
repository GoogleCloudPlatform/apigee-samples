# Mutual TLS Northbound Security

This sample shows how to configure mTLS using a GCP Private CA (Certificate Authority) on an existing GLB (global load balancer).

Let's get started!

## Setup instructions

1. Navigate to the 'mtls-northbound' directory in the Cloud Shell.

```bash
cd mtls-northbound
```

2. Ensure you have an active GCP account selected in the Cloud shell

```sh
gcloud auth login
```

3. Edit the `env.sh` and configure the ENV vars specific to your installation.

* `PROJECT` the project where your Apigee organization is located.
* `APIGEE_HOST` the externally reachable hostname of the Apigee environment group that contains APIGEE_ENV.
* `APIGEE_ENV` the Apigee environment where the demo resources should be created.
* `TARGET_PROXY` the Target HTTPS Proxy used in your GLB configuration.
* `BACKEND_SERVICE` the Backend Service used in your GLB configuration.
* `POOL` the name of the Private CA pool (e.g. partners-pool).
* `ROOT` the name of the Root CA in the pool (e.g. partner1-root-ca).
* `TRUST_CONFIG` the name of the Trust Configuration for the Root CA (e.g. partner1-trust-config).
* `CERT_NAME` the name of the client certificate used in API calls (e.g. partner-1-client-1).

Now source the `env.sh` file

```bash
source ./env.sh
```

## Create CA pool and root CAs
We'll use the use case of multiple partners communicating with our APIs.

### CA Pool
Create a pool for each of the partner CAs.
```
gcloud privateca pools create ${POOL} --location=us-east1
```

### Root CAs
Create a Root CA.
```
gcloud privateca roots create ${ROOT} \
    --pool=${POOL} \
    --subject="CN=partner1-ca, O=Partner 1" \
    --location=us-east1 \
    --auto-enable
```

## Create Trust Configuration
The trust configuration can be used by multiple Server TLS Policies (e.g. lenient, strict).

First, get the private CA root certificate.
```
gcloud privateca roots describe ${ROOT} \
   --pool=${POOL} \
   --location=us-east1 \
   --format='value(pemCaCertificates)' > ${ROOT}.cert
```
Then format to remove newlines and create the trust config yaml file. 
```
export ROOT_PEM=$(cat ${ROOT}.cert | sed 's/^[ ]*//g' | tr '\n' $ | sed 's/\$/\\n/g')

cat << EOF > ${TRUST_CONFIG}.yaml
name: ${TRUST_CONFIG}
trustStores:
- trustAnchors:
   - pemCertificate: "${ROOT_PEM?}"
EOF
```
Finally create the trust config.
```
gcloud beta certificate-manager trust-configs import ${TRUST_CONFIG} --source=${TRUST_CONFIG}.yaml
```

## Create Server TLS Policies
Create policy representations for "lenient" and "strict", 
then you can easily switch between them by updating the Target HTTPS Proxy.

### Lenient
Create the lenient policy yaml file.
```
cat << EOF > ${ROOT}-lenient.yaml
name: ${ROOT}-lenient
mtlsPolicy:
  clientValidationMode: ALLOW_INVALID_OR_MISSING_CLIENT_CERT
  clientValidationTrustConfig: projects/${PROJECT}/locations/global/trustConfigs/${TRUST_CONFIG}
EOF
```
Create the lenient policy.
```
gcloud beta network-security server-tls-policies import ${ROOT}-lenient \
    --source=${ROOT}-lenient.yaml \
    --location=global
```

### Strict
Create the strict policy yaml file.
```
cat << EOF > ${ROOT}-strict.yaml
name: ${ROOT}-strict
mtlsPolicy:
  clientValidationMode: REJECT_INVALID
  clientValidationTrustConfig: projects/${PROJECT}/locations/global/trustConfigs/${TRUST_CONFIG}
EOF
```
Create the strict policy.
```
gcloud beta network-security server-tls-policies import ${ROOT}-strict \
    --source=${ROOT}-strict.yaml \
    --location=global
```

## Prepare Configuration files to Update the GLB
The steps are the same for any Application GLB, just find the Target HTTPS Proxy for the GLB and update.
You can easily switch between the TLS policies by creating representations for each configuration.

Find the Target HTTPS Proxy for your GLB.
```
gcloud compute target-https-proxies list
                                SSL_CERTIFICATES            URL_MAP              REGION    CERTIFICATE_MAP
apigee-proxy-https-proxy        gm-xapi-kurtkanaskie-net    apigee-proxy-url-map
apigee-proxy-modern-https-proxy gm-m-xapi-kurtkanaskie-net  apigee-proxy-modern-url-map
```

### Create Target HTTPS Proxy configurations
We'll create multiple configurations so we can easily switch between them, one for "none", "lenient" and "strict".

Export the Target HTTPS Proxy configuration and store in a "none" file.
This allows us to remove the Server TLS Policy later.
```
export TARGET_PROXY=apigee-proxy-https-proxy

gcloud compute target-https-proxies export ${TARGET_PROXY} \
   --global \
   --destination=${TARGET_PROXY}-none.yaml
```
Copy to create new files for "lenient" and "strict" and add the appropriate Server TLS Policy names.

Lenient
```
cp ${TARGET_PROXY}-none.yaml ${TARGET_PROXY}-lenient.yaml

echo "serverTlsPolicy: //networksecurity.googleapis.com/projects/${PROJECT}/locations/global/serverTlsPolicies/${ROOT}-lenient" >> ${TARGET_PROXY}-lenient.yaml
```

Strict
```
cp ${TARGET_PROXY}-none.yaml ${TARGET_PROXY}-strict.yaml

echo "serverTlsPolicy: //networksecurity.googleapis.com/projects/${PROJECT}/locations/global/serverTlsPolicies/${ROOT}-strict" >> ${TARGET_PROXY}-strict.yaml
```

## Update the GLB Backend Service with mTLS headers
First, find the Backend Service(s) for the GLB.
The custom header configuration must be added to each Backend Service, in this example we only have one.
For example:
```
gcloud compute backend-services list --global
NAME                  BACKENDS                                                                                PROTOCOL
apigee-proxy-backend  us-east1/instanceGroups/apigee-mig-us-east1,us-west1/instanceGroups/apigee-mig-us-west1 HTTPS
```
[Update the custom headers](https://cloud.google.com/load-balancing/docs/https/custom-headers-global#mtls-variables).
We'll also turn on logging so we can check Cloud Logging for errors in "strict" mode.

**CAUTION**: Check if you already have custom headers configured so as not to overwrite them. Use:
```
gcloud compute backend-services describe $BACKEND_SERVICE --global --format=json > $BACKEND_SERVICE.json
```

**NOTE**: There's a limit of 16 custom headers.
```
export BACKEND_SERVICE=apigee-proxy-backend

gcloud compute backend-services update apigee-proxy-backend \
  --global \
  --enable-logging --logging-sample-rate=1 \
  --custom-request-header="X-Client-Cert-Present:{client_cert_present}" \
  --custom-request-header="X-Client-Cert-Chain-Verified:{client_cert_chain_verified}" \
  --custom-request-header="X-Client-Cert-Error:{client_cert_error}" \
  --custom-request-header="X-Client-Cert-Hash:{client_cert_sha256_fingerprint}" \
  --custom-request-header="X-Client-Cert-Serial-Number:{client_cert_serial_number}" \
  --custom-request-header="X-Client-Cert-SPIFFE:{client_cert_spiffe_id}" \
  --custom-request-header="X-Client-Cert-URI-SANs:{client_cert_uri_sans}" \
  --custom-request-header="X-Client-Cert-DNSName-SANs:{client_cert_dnsname_sans}" \
  --custom-request-header="X-Client-Cert-Valid-Not-Before:{client_cert_valid_not_before}" \
  --custom-request-header="X-Client-Cert-Valid-Not-After:{client_cert_valid_not_after}"
```

## Deploy Apigee Proxy
Now that the Private CA pool, Root CAs, GLB configuration files and custom headers are setup we are ready to begin testing.

Next, let's deploy the "sample-mtls" proxy. 

```bash
./deploy-sample-mtls-proxy.sh
```

---
## Test Proxy

Now that our API proxy is deployed, let's test to see what a non-mTLS response looks like.\
 Notice there are no values in the "mtls_details" properties.
```
curl https://$APIGEE_HOST/sample-mtls

{
    "request":"GET https://xapi-dev.kurtkanaskie.net/sample-mtls",
    "status":"200",
    "reason":"OK",
    "organization":"apigeex-mint-kurt",
    "environment":"dev",
    "tls_protocol":"TLSv1.3",
    "tls_cipher":"TLS_AES_128_GCM_SHA256",
    "tls_server.name":"xapi-dev.kurtkanaskie.net",
    "tls_session.id":"",
    "mtls_details":{
        "x-client-cert-error":"",
        "x-client-cert-present":"",
        "x-client-cert-chain-verified":"",
        "x-client-cert-serial-number":"",
        "x-client-cert-hash":"",
        "x-client-cert-dnsname-sans":"",
        "x-client-cert-dnsname-sans-decoded":"",
        "x-client-cert-uri-sans":"",
        "x-client-cert-uri-sans-decoded":"",
        "x-client-cert-spiffe":"",
        "x-client-cert-valid-not-before":"",
        "x-client-cert-valid-not-after":""
    }
}
```

### Update Target HTTPS Proxy for "lenient" security
```
gcloud compute target-https-proxies import ${TARGET_PROXY} \
   --global \
   --source=${TARGET_PROXY}-lenient.yaml  \
   --quiet
```

Wait a couple minutes for the configuration to propogate and test the API again.\
You may see the following error before the configuration is complete.
```
curl: (56) Failure when receiving data from the peer
```
When complete, notice the 400 and the custom header details in the response.\
Notice the value of "x-client-cert-chain-verified" is false, we use that in a condition to execute the Rasie Fault policy. \
The value in "x-client-cert-error" indicates the type of error. \
The possible errors can be found [here](https://cloud.google.com/load-balancing/docs/https/https-logging-monitoring#failure-messages).
```
curl https://$APIGEE_HOST/sample-mtls

{
    "request":"GET https://xapi-dev.kurtkanaskie.net/sample-mtls",
    "status":"400",
    "reason":"Bad Request",
    "error":"Bad Certificate Request",
    "description":"Invalid or missing client certificate",
    "mtls_error_details":{
        "x-client-cert-error":"client_cert_not_provided",
        "x-client-cert-present":"false",
        "x-client-cert-chain-verified":"false",
        "x-client-cert-serial-number":"",
        "x-client-cert-hash":"",
        "x-client-cert-dnsname-sans":"",
        "x-client-cert-uri-sans":"",
        "x-client-cert-spiffe":"",
        "x-client-cert-valid-not-before":"",
        "x-client-cert-valid-not-after":""
    }
}
```
#### Test with valid certificte
Now lets create valid client certificates from the Root CA.

**NOTE:** You may be required to install Python and the Pyca library if you see this error when creating certificates:
```
Cannot load the Pyca cryptography library. 
Either the library is not installed, or site packages are not enabled for the Google Cloud SDK. 
Please consult Cloud KMS documentation on adding Pyca to Google Cloud SDK for further instructions.
https://cloud.google.com/kms/docs/cryptos
```
After installing Python and Pyca set:
```
export CLOUDSDK_PYTHON_SITEPACKAGES=1
```
Create a valid certificate and key, being sure to use "--extended-key-usages=client_auth".

```
export CERT_NAME="partner-1-client-1"
gcloud privateca certificates create ${CERT_NAME} \
    --issuer-pool=${POOL} \
    --ca=${ROOT} \
    --issuer-location=us-east1 \
    --generate-key \
    --extended-key-usages=client_auth \
    --key-output-file=./${CERT_NAME}-key.pem \
    --cert-output-file=./${CERT_NAME}-cert.pem \
    --dns-san=${APIGEE_HOST} \
    --uri-san=https://${APIGEE_HOST} \
    --subject="C=US,ST=Pennsylvania,L=Macungie,O=Google LLC,CN=${APIGEE_HOST}"
```

Test with the valid certificate and key.

**NOTE:** The values in "x-client-cert-dnsname-sans" and "x-client-cert-uri-sans" are base64 encoded values for "--dns-san" and "--uri-san" respectively. They are shown decoded in the response by using the [decodeBase64 message template function](https://cloud.google.com/apigee/docs/api-platform/reference/message-template-intro#base64-encoding-functions) in the Assign Message policy.

Notice the value of "x-client-cert-chain-verified" is true.
```
curl https://$APIGEE_HOST/sample-mtls --cert ./${CERT_NAME}-cert.pem --key ./${CERT_NAME}-key.pem

{
    "request":"GET https://xapi-dev.kurtkanaskie.net/sample-mtls",
    "status":"200",
    "reason":"OK",
    "organization":"apigeex-mint-kurt",
    "environment":"dev",
    "tls_protocol":"TLSv1.3",
    "tls_cipher":"TLS_AES_128_GCM_SHA256",
    "tls_server.name":"xapi-dev.kurtkanaskie.net",
    "tls_session.id":"",
    "mtls_details":{
        "x-client-cert-error":"",
        "x-client-cert-present":"true",
        "x-client-cert-chain-verified":"true",
        "x-client-cert-serial-number":"00:ad:3e:0e:bc:c3:d4:f4:2d:ae:5b:21:3b:e4:cb:8b:f4:9d:49:a1",
        "x-client-cert-hash":"om8vGt3r6eTx5TI1kCeNKRJYZTUreIbHGu+Gu8FN8To",
        "x-client-cert-dnsname-sans":"eGFwaS1kZXYua3VydGthbmFza2llLm5ldA==",
        "x-client-cert-dnsname-sans-decoded":"xapi-dev.kurtkanaskie.net",
        "x-client-cert-uri-sans":"aHR0cHM6Ly94YXBpLWRldi5rdXJ0a2FuYXNraWUubmV0",
        "x-client-cert-uri-sans-decoded":"https://xapi-dev.kurtkanaskie.net",
        "x-client-cert-spiffe":"",
        "x-client-cert-valid-not-before":"2023-09-12T14:55:19+00:00",
        "x-client-cert-valid-not-after":"2023-10-12T14:55:18+00:00"
    }
}
```
#### Test with invalid certificate
Create a certificate and key without "-extended-key-usages=client_auth".

```
export INVALID_CERT_NAME="partner-1-invalid-1"
gcloud privateca certificates create ${INVALID_CERT_NAME} \
    --issuer-pool=${POOL} \
    --ca=${ROOT} \
    --issuer-location=us-east1 \
    --generate-key \
    --key-output-file=./${INVALID_CERT_NAME}-key.pem \
    --cert-output-file=./${INVALID_CERT_NAME}-cert.pem \
    --dns-san=${APIGEE_HOST} \
    --uri-san=https://${APIGEE_HOST} \
    --subject="C=US,ST=Pennsylvania,L=Macungie,O=Google LLC,CN=${APIGEE_HOST}"
```
Test with the valid certificate and key.\
Notice the value of "x-client-cert-chain-verified" is false, we use that in a condition to execute the Rasie Fault policy. \
The value in "x-client-cert-error" indicates the type of error. \
The possible errors can be found [here](https://cloud.google.com/load-balancing/docs/https/https-logging-monitoring#failure-messages).
```
curl https://$APIGEE_HOST/sample-mtls --cert ./${INVALID_CERT_NAME}-cert.pem --key ./${INVALID_CERT_NAME}-key.pem

{
    "request":"GET https://xapi-dev.kurtkanaskie.net/sample-mtls",
    "status":"400",
    "reason":"Bad Request",
    "error":"Bad Certificate Request",
    "description":"Invalid or missing client certificate",
    "mtls_error_details":{
        "x-client-cert-error":"client_cert_chain_invalid_eku",
        "x-client-cert-present":"true",
        "x-client-cert-chain-verified":"false",
        "x-client-cert-serial-number":"",
        "x-client-cert-hash":"G+SrKkjfs6Kom73j7sp+hY6/5kZ+UjPdBDEyiaOUk08",
        "x-client-cert-dnsname-sans":"",
        "x-client-cert-uri-sans":"",
        "x-client-cert-spiffe":"",
        "x-client-cert-valid-not-before":"",
        "x-client-cert-valid-not-after":""
    }
}
```
### Update Target HTTPS Proxy for "strict" security
Now that we've verified the configuration in "lenient" mode, we can switch to "strict" mode.
```
gcloud compute target-https-proxies import ${TARGET_PROXY} \
   --global \
   --source=${TARGET_PROXY}-strict.yaml  \
   --quiet
```

Wait a couple minutes for the configuration to propogate and test the API again.\
First lets test with no certificates to ensure the confuguration has propogated.\
You may see the following error before the configuration is complete.
```
curl https://$APIGEE_HOST/sample-mtls 
curl: (56) Recv failure: Connection reset by peer
```
Once the configuration has propogated note the response is from curl, not the Raise Fault policy, since the request was rejected by the GLB Target HTTPS Proxy due to the "strict" configuration.

```
curl https://$APIGEE_HOST/sample-mtls 
curl: (56) Failure when receiving data from the peer

```
#### Test with valid certificate and key
Now lets test with the valid certificate and key.

```
curl https://$APIGEE_HOST/sample-mtls --cert ./${CERT_NAME}-cert.pem --key ./${CERT_NAME}-key.pem

{
    "request":"GET https://xapi-dev.kurtkanaskie.net/sample-mtls",
    "status":"200",
    "reason":"OK",
    "organization":"apigeex-mint-kurt",
    "environment":"dev",
    "tls_protocol":"TLSv1.3",
    "tls_cipher":"TLS_AES_128_GCM_SHA256",
    "tls_server.name":"xapi-dev.kurtkanaskie.net",
    "tls_session.id":"",
    "mtls_details":{
        "x-client-cert-error":"",
        "x-client-cert-present":"true",
        "x-client-cert-chain-verified":"true",
        "x-client-cert-serial-number":"00:ad:3e:0e:bc:c3:d4:f4:2d:ae:5b:21:3b:e4:cb:8b:f4:9d:49:a1",
        "x-client-cert-hash":"om8vGt3r6eTx5TI1kCeNKRJYZTUreIbHGu+Gu8FN8To",
        "x-client-cert-dnsname-sans":"eGFwaS1kZXYua3VydGthbmFza2llLm5ldA==",
        "x-client-cert-dnsname-sans-decoded":"xapi-dev.kurtkanaskie.net",
        "x-client-cert-uri-sans":"aHR0cHM6Ly94YXBpLWRldi5rdXJ0a2FuYXNraWUubmV0",
        "x-client-cert-uri-sans-decoded":"https://xapi-dev.kurtkanaskie.net",
        "x-client-cert-spiffe":"",
        "x-client-cert-valid-not-before":"2023-09-12T14:55:19+00:00",
        "x-client-cert-valid-not-after":"2023-10-12T14:55:18+00:00"
    }
}
```

#### Test with invalid certificate and key
Now lets test with the invalid certificate and key.\
Again, notice the response is from curl, not the Raise Fault policy in the proxy.

```
curl https://$APIGEE_HOST/sample-mtls --cert ./${INVALID_CERT_NAME}-cert.pem --key ./${INVALID_CERT_NAME}-key.pem
curl: (56) Recv failure: Connection reset by peer
```

### Check GLB Logs
Since we have enforced strict mTLS and our requests are being rejected by the GLB, lets take a look at Cloud Logging to see the errors there.

GLB Failures: https://cloud.google.com/load-balancing/docs/https/https-logging-monitoring#failure-messages \
See logs: https://cloud.google.com/load-balancing/docs/https/https-logging-monitoring#log-fwd-rule

**NOTE:** Log entries will only exist when clientValidationMode is set to REJECT_INVALID and not ALLOW_INVALID_OR_MISSING_CLIENT_CERT.

Find the forwarding rule for the GLB. For example:
```
gcloud compute forwarding-rules list 
NAME                                              REGION    IP_ADDRESS      IP_PROTOCOL  TARGET
apigee-proxy-https-lb-rule                  34.149.167.159  TCP          apigee-proxy-https-proxy
apigee-proxy-modern-https-lb-rule           34.160.201.100  TCP          apigee-proxy-modern-https-proxy
```

Navigate to [Cloud Logging in the GCP Console](https://pantheon.corp.google.com/logs/query). 

Enter the query for you forwarding rule.
```
jsonPayload.statusDetails=~"client_cert"
jsonPayload.@type="type.googleapis.com/google.cloud.loadbalancing.type.LoadBalancerLogEntry"
resource.labels.forwarding_rule_name=apigee-proxy-https-lb-rule
```
Expand a few of the entries to observe the value in "statusDetails".\
This one is when no certificate was provided.
```
{
  "insertId": "1w9kh9pf2a1un6",
  "jsonPayload": {
    "statusDetails": "client_cert_not_provided",
    "@type": "type.googleapis.com/google.cloud.loadbalancing.type.LoadBalancerLogEntry",
    "backendTargetProjectNumber": "projects/388897613316",
    "remoteIp": "35.199.77.186"
  },
  "httpRequest": {
    "remoteIp": "35.199.77.186",
    "latency": "0s"
  },
  "resource": {
    "type": "http_load_balancer",
    "labels": {
      "backend_service_name": "",
      "project_id": "apigeex-mint-kurt",
      "url_map_name": "",
      "forwarding_rule_name": "apigee-proxy-https-lb-rule",
      "zone": "global",
      "target_proxy_name": ""
    }
  },
  "timestamp": "2023-09-12T15:47:55.884550Z",
  "severity": "INFO",
  "logName": "projects/apigeex-mint-kurt/logs/requests",
  "receiveTimestamp": "2023-09-12T15:47:57.169721044Z"
}
```
This one is from the invalid certificate request, without "-extended-key-usages=client_auth".
```
{
  "insertId": "chsaekfqcfp9z",
  "jsonPayload": {
    "backendTargetProjectNumber": "projects/388897613316",
    "remoteIp": "131.106.40.233",
    "statusDetails": "client_cert_chain_invalid_eku",
    "@type": "type.googleapis.com/google.cloud.loadbalancing.type.LoadBalancerLogEntry"
  },
  "httpRequest": {
    "remoteIp": "131.106.40.233",
    "latency": "0s"
  },
  "resource": {
    "type": "http_load_balancer",
    "labels": {
      "project_id": "apigeex-mint-kurt",
      "forwarding_rule_name": "apigee-proxy-https-lb-rule",
      "backend_service_name": "",
      "url_map_name": "",
      "zone": "global",
      "target_proxy_name": ""
    }
  },
  "timestamp": "2023-09-14T15:14:05.630020Z",
  "severity": "INFO",
  "logName": "projects/apigeex-mint-kurt/logs/requests",
  "receiveTimestamp": "2023-09-14T15:14:06.670569225Z"
}
```

## Conclusion & Cleanup

Congratulations! You've successfully configured mTLS on your GLB and tested API requests in "lenient" and "strict" mode. You've also used Cloud Logging to observe errors when using "strict" mode.

```bash
./clean-up-mtls.sh
```
