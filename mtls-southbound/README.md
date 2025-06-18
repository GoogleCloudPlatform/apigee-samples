# Apigee Mutual TLS Southbound Security

This sample shows how to configure mTLS for southbound services from Apigee.

![Apigee mTLS Southbound Sample](./img/architecture.png)

## About mTLS for Apigee southbound connections

- [Apigee Docs on TLS](https://cloud.google.com/apigee/docs/api-platform/system-administration/options-configuring-tls)

## Prerequisites
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) will be used for automating GCP tasks, see the docs site above for installation instructions.
- [apigeecli](https://github.com/apigee/apigeecli) will be used for Apigee automation, and can easily be installed like this (see apigeecli docs for more information):
```sh
curl -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh -
echo $'\nPATH=$PATH:$HOME/.apigeecli/bin' >> ~/.bashrc
source ~/.bashrc
```
- GCP roles needed:
  - roles/compute.instanceAdmin - needed to create a VM.
  - roles/compute.networkAdmin - needed to create a firewall rule to allow the VM to get scp commands on port 22.
  - roles/apigee.apiAdminV2 - needed to deploy an Apigee proxy.
  - roles/apigee.environmentAdmin - needed to manage the Keystore and Target configuration.

## Step 1: Set your GCP project environment variables

To begin, set your environment variables to be used by creating an `.env` file, and filling your variables in.

```sh
cat > .env <<EOF
export PROJECT_ID=YOUR_PROJECT_ID # an existing GCP project id that you have rights to use
export REGION=europe-west1 # for example europe-west1
export APIGEE_ENV=dev # for example dev or eval
export ZONE=europe-west1-c # for example europe-west1-c
export VM_NAME=mtls-vm1 # or change to any name
export VM_IP=YOUR_VM_EXTERNAL_IP # fill this in after creating the VM
EOF
```

Now open the `.env` file, and set *PROJECT_ID* to your GCP project, and optionally *REGION*, *APIGEE_ENV*, *ZONE*, and *VM_NAME* to different values if you prefer.

## Step 2: Create a VM with nginx using mTLS

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

Now set the environment variable `export VM_IP=YOUR_VM_EXTERNAL_IP` with the EXTERNAL IP that is displayed in the VM create output, or update and source your `.env` file if you created one.

## Step 3: Create self-signed certificate and key

Now we will create a self-signed certificate and key to test with.

```sh
# create cert.pem certificate and set to allow our VM_IP as Alt.
openssl req -subj '/CN=ssl.test.local' -x509 -new -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365 -nodes -addext "keyUsage = digitalSignature,keyAgreement" -addext "extendedKeyUsage = serverAuth, clientAuth" -addext "subjectAltName = DNS:ssl.test.local, DNS:localhost, IP:127.0.0.1, IP:$VM_IP"

# create PCKS12 export, use 'test' as password
openssl pkcs12 -export -out client.p12 -inkey key.pem -in cert.pem

# verify certificate, should return OK
openssl verify -CAfile cert.pem cert.pem
```

## Step 4: Set VM cert and nginx config

Now we will sync the cert and key to the VM, and set the nginx config file as well.

```sh
# copy cert, key and nginx.conf files to VM /etc/nginx dir
gcloud compute scp cert.pem key.pem nginx.conf $VM_NAME:/etc/nginx --zone=$ZONE --project $PROJECT_ID

# restart nginx to apply config
gcloud compute ssh $VM_NAME --zone=$ZONE --project=$PROJECT_ID --command="sudo nginx -s reload"
```

## Step 5: Test calling VM directly with cert and key

Now that our nginx is running with our cert and key, we can call it using `curl`.

```sh
# call with just the cacert, should get the message "blocked access to mTLS-protected resource"
curl -v https://$VM_IP --cacert cert.pem

# now call with cert and key, should get the message "access to mTLS-protected resource"
curl -v https://$VM_IP --cacert cert.pem --key key.pem --cert cert.pem
```

## Step 6: Create Apigee Keystore for cert and key to use in a proxy

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

## Step 7: Test Apigee API proxy

```sh
# get Apigee hostname, this will get the first one from the first envgroup, if not correct then adjust..
HOSTNAME=$(apigeecli envgroups list -o $PROJECT_ID | jq --raw-output '.environmentGroups[0].hostnames[0]')

# call Apigee API proxy
curl https://$HOSTNAME/v1/samples/mtls-service
# you should get back the message "access to mTLS-protected resource" since Apigee has the mTLS cert and key. Yay!
```

## Step 8 (Optional): Test nginx service locally with Docker

In case you would like to test the nginx configuration and mTLS access locally with Docker, this can easily be done with the [nginx Docker image](https://hub.docker.com/_/nginx).

```sh
# start nginx container
docker run -v "./nginx.conf:/etc/nginx/nginx.conf:ro" -v "./cert.pem:/etc/nginx/cert.pem:ro" -v "./key.pem:/etc/nginx/key.pem:ro" -p 8080:443 -it nginx

# test without key
curl -v https://ssl.test.local:8080 --resolve ssl.test.local:8080:127.0.0.1 --cacert cert.pem

# test with key
curl -v https://ssl.test.local:8080 --resolve ssl.test.local:8080:127.0.0.1 --cacert cert.pem --key key.pem --cert cert.pem
```

## Step 9: Cleanup resources

Don't forget to cleanup all of our resources.

```sh
# delete VM
gcloud compute instances delete $VM_NAME --zone $ZONE --project $PROJECT_ID
# undeploy and delete Apigee proxy
apigeecli apis undeploy -e $APIGEE_ENV -n SecureBackendProxy-v1 -o $PROJECT_ID -t $(gcloud auth print-access-token)
apigeecli apis delete -n SecureBackendProxy-v1 -o $PROJECT_ID -t $(gcloud auth print-access-token)
# delete Apigee Target and Keystore
apigeecli targetservers delete -n mtls-service -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)
apigeecli keystores delete -n mtls-keystore1 -o $PROJECT_ID -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)
```

## References

- Very helpful gist on setting up mTLS in nginx with a self-signed cert: <https://gist.github.com/jeduardo/8a4c4465e87767c42ffcdc6b3e9e8396>
- Great article on setting up southbound mTLS in Apigee - <https://medium.com/google-cloud/configuring-mtls-for-apigee-x-southbound-traffic-flow-eb91f381b60f>
