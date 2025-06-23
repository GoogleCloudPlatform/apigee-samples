gcloud compute instances delete $VM_NAME --zone $ZONE --project $PROJECT_ID
# undeploy and delete Apigee proxy
apigeecli apis undeploy -e $APIGEE_ENV -n mtls-southbound-v1 -o $PROJECT_ID -t $(gcloud auth print-access-token)
apigeecli apis delete -n mtls-southbound-v1 -o $PROJECT_ID -t $(gcloud auth print-access-token)
# delete Apigee Target and Keystore
apigeecli targetservers delete -n mtls-service -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)
apigeecli keystores delete -n mtls-keystore1 -o $PROJECT_ID -e $APIGEE_ENV -o $PROJECT_ID -t $(gcloud auth print-access-token)