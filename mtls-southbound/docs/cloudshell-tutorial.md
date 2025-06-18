# Apigee mTLS Southbound Tutorial

This sample creates a small VM that requires mTLS to access, as well as an Apigee proxy with a truststore and certificate to connect to the VM as a backend service.

Let's get started!

---

## Prepare project dependencies

### 1. Ensure that prerequisite tools are installed

We will be using the [apigeecli](https://github.com/apigee/apigeecli) for an Apigee deployment, you can make sure it is installed in your Cloud Shell with this script

```sh
curl -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh -
echo $'\nPATH=$PATH:$HOME/.apigeecli/bin' >> ~/.bashrc
source ~/.bashrc
```

### 2. Ensure you have an active GCP account selected in the Cloud Shell

```sh
gcloud auth login
```

## Set environment variables

First create an `.env` file to store the environment variables.

```sh
cd ./mtls-southbound
cat > .env <<EOF
export PROJECT_ID=YOUR_PROJECT_ID # an existing GCP project id that you have rights to use
export REGION=europe-west1 # for example europe-west1
export APIGEE_ENV=dev # for example dev or eval
export ZONE=europe-west1-c # for example europe-west1-c
export VM_NAME=mtls-vm1 # or change to any name
export VM_IP=YOUR_VM_EXTERNAL_IP # fill this in after creating the VM
EOF
```

Now open the file, and set *PROJECT_ID* to your GCP project, and optionally *REGION*, *APIGEE_ENV*, *ZONE*, and *VM_NAME* to different values if you prefer.

<walkthrough-editor-open-file filePath="mtls-southbound/.env">here</walkthrough-editor-open-file>

Now source the .env file.

```sh
source .env
```

## Create a VM with nginx using mTLS

If you already have an mTLS endpoint with certificate and key, you can skip this step. First we will create two firewall rules to allow traffic to the VM, and then we will create a small VM with [nginx](https://nginx.org/) running to handle the mTLS backend requests.

```sh
# create firewall rules for port 22.
gcloud compute firewall-rules create allow22 --allow tcp:22 --project $PROJECT_ID --target-tags allow22

# create our backend VM, with a startup script to install nginx and let us write files to the /etc/nginx dir.
gcloud compute instances create $VM_NAME \
 --project=$PROJECT_ID \
  --zone=$ZONE \
  --image=debian-12-bookworm-v20250610 \
  --image-project=debian-cloud \
  --machine-type=e2-medium \
  --tags=https-server,allow22 \
 --metadata=startup-script='#! /bin/bash
apt update
apt -y install nginx
sudo chmod -R 777 /etc/nginx'
```

### Set VM_IP environment variable

Now that we have the VM created, let's set the **VM_IP** environment variable to the External IP address that you see form the create operation.

<walkthrough-editor-open-file filePath="mtls-southbound/.env">here</walkthrough-editor-open-file>

Now source the .env file.

```sh
source .env
```

## Create self-signed certificate and key

Now we will create a self-signed certificate and key to test with.

```sh
# create cert.pem certificate and set to allow our VM_IP as Alt.
openssl req -subj '/CN=ssl.test.local' -x509 -new -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365 -nodes -addext "keyUsage = digitalSignature,keyAgreement" -addext "extendedKeyUsage = serverAuth, clientAuth" -addext "subjectAltName = DNS:ssl.test.local, DNS:localhost, IP:127.0.0.1, IP:$VM_IP"

# create PCKS12 export, use 'test' as password
openssl pkcs12 -export -out client.p12 -inkey key.pem -in cert.pem

# verify certificate, should return OK
openssl verify -CAfile cert.pem cert.pem
```

### Set VM cert and nginx config

Now we will sync the cert and key to the VM, and set the nginx config file as well.

```sh
# copy cert, key and nginx.conf files to VM /etc/nginx dir
gcloud compute scp cert.pem key.pem nginx.conf $VM_NAME:/etc/nginx --zone=$ZONE --project $PROJECT_ID

# restart nginx to apply config
gcloud compute ssh $VM_NAME --zone=$ZONE --project=$PROJECT_ID --command="sudo nginx -s reload"
```

### Test calling VM directly with cert and key

Test calling the VM to see if nginx is reachable, and we can successfully call the endpoint with our certificate and key.

```sh
# call with just the cacert, should get the message "blocked access to mTLS-protected resource"
curl -v https://$VM_IP --cacert cert.pem

# now call with cert and key, should get the message "access to mTLS-protected resource"
curl -v https://$VM_IP --cacert cert.pem --key key.pem --cert cert.pem
```

## Create Apigee Keystore and Proxy

```sh
# create Apigee keystore
apigeecli keystores create -n mtls-keystore1 -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)

# create Apigee key and cert
apigeecli keyaliases create -s test-key1 -f keycertfile -k mtls-keystore1 --key-filepath key.pem --cert-filepath cert.pem -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)

# create Apigee cert
apigeecli keyaliases create -s test-cert1 -f keycertfile -k mtls-keystore1 --cert-filepath cert.pem -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)

# create Apigee target server
apigeecli targetservers create -c true -s "$VM_IP" -i true --keyalias test-key1 --keystore mtls-keystore1 -n mtls-service -p 443 --tls true --tlsenforce false --truststore mtls-keystore1 -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)

# deploy Apigee proxy
apigeecli apis create bundle -f apiproxy --name SecureBackendProxy-v1 -o $PROJECT_ID -e $APIGEE_ENV --ovr -t $(gcloud auth print-access-token)
```

### Test Apigee API proxy to reach mTLS service

Let's do a test call to the Apigee API proxy to see if we can reach our mTLS backend VM.

```sh
# get Apigee hostname, this will get the first one from the first envgroup, if not correct then adjust..
HOSTNAME=$(apigeecli envgroups list -o $PROJECT_ID | jq --raw-output '.environmentGroups[0].hostnames[0]')

# call Apigee API proxy
curl https://$HOSTNAME/v1/samples/mtls-service
# you should get back the message "access to mTLS-protected resource" since Apigee has the mTLS cert and key. Yay!
```

## Congratulations

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

You're all set!

**Don't forget to clean up after yourself**. Execute the following commands to undeploy and delete all sample resources.

```sh
gcloud compute instances delete $VM_NAME --zone $ZONE --project $PROJECT_ID
# undeploy and delete Apigee proxy
apigeecli apis undeploy -e $APIGEE_ENV -n SecureBackendProxy-v1 -o $PROJECT_ID -t $(gcloud auth print-access-token)
apigeecli apis delete -n SecureBackendProxy-v1 -o $PROJECT_ID -t $(gcloud auth print-access-token)
# delete Apigee Target and Keystore
apigeecli targetservers delete -n mtls-service -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)
apigeecli keystores delete -n mtls-keystore1 -o $PROJECT_ID -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)
```
