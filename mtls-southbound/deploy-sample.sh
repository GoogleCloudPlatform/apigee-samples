#!/bin/bash

# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

echo "Installing apigeecli..."
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Creating firewall rule to allow port 22 for config files sync..."
gcloud compute firewall-rules create allow22 --allow tcp:22 --project $PROJECT_ID --target-tags allow22

echo "Creating VM with sample mTLS service..."
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
sudo chmod -R 077 /etc/nginx'

sleep 10

echo "Update VM ip address in env file..."
VM_IP=$(gcloud compute instances describe $VM_NAME --project=$PROJECT_ID --zone=$ZONE --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
sed -i "/export VM_IP=/c\export VM_IP=\"$VM_IP\"" env.sh

echo "Creating self-signed certificate and key..."
openssl req -subj '/CN=ssl.test.local' -x509 -new -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365 -nodes -addext "keyUsage = digitalSignature,keyAgreement" -addext "extendedKeyUsage = serverAuth, clientAuth" -addext "subjectAltName = DNS:ssl.test.local, DNS:localhost, IP:127.0.0.1, IP:$VM_IP"
openssl pkcs12 -export -out client.p12 -inkey key.pem -in cert.pem
openssl verify -CAfile cert.pem cert.pem
# copy cert, key and nginx.conf files to VM /etc/nginx dir
gcloud compute scp cert.pem key.pem nginx.conf $VM_NAME:/etc/nginx --zone=$ZONE --project $PROJECT_ID
# restart nginx to apply config
gcloud compute ssh $VM_NAME --zone=$ZONE --project=$PROJECT_ID --command="sudo nginx -s reload"

echo "Deploy Apigee assets..."
# create Apigee keystore
apigeecli keystores create -n mtls-keystore1 -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)
# create Apigee key and cert
apigeecli keyaliases create -s test-key1 -f keycertfile -k mtls-keystore1 --key-filepath key.pem --cert-filepath cert.pem -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)
# create Apigee cert
apigeecli keyaliases create -s test-cert1 -f keycertfile -k mtls-keystore1 --cert-filepath cert.pem -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)
# create Apigee target server
apigeecli targetservers create -c true -s "$VM_IP" -i true --keyalias test-key1 --keystore mtls-keystore1 -n mtls-service -p 443 --tls true --tlsenforce false --truststore mtls-keystore1 -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)
# deploy Apigee proxy
apigeecli apis create bundle -f apiproxy --name mtls-southbound-v1 -o $PROJECT_ID -e $APIGEE_ENV --ovr -t $(gcloud auth print-access-token)