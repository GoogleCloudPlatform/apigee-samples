if [ -z "$PROJECT_ID" ]; then
  echo "No PROJECT_ID variable set"
  exit
fi

if [ -z "$REGION" ]; then
  echo "No REGION variable set"
  exit
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit
fi

if [ -z "$APIGEE_HOST" ]; then
  echo "No APIGEE_HOST variable set"
  exit
fi

if [ -z "$APIGEE_PORTAL_ID" ]; then
  echo "No APIGEE_PORTAL_ID variable set"
  exit
fi

echo "💻 Registering an unmanaged API in API Hub to the 'Test' environment..."

# copy definitions and set env variables in local files
cp apihub-api.json apihub-api.local.json
sed -i "s,PROJECT_ID,$PROJECT_ID,g" ./apihub-api.local.json
sed -i "s,REGION,$REGION,g" ./apihub-api.local.json
cp apihub-api-version.json apihub-api-version.local.json
sed -i "s,PROJECT_ID,$PROJECT_ID,g" ./apihub-api-version.local.json
sed -i "s,REGION,$REGION,g" ./apihub-api-version.local.json
cp apihub-api-deployment.json apihub-api-deployment.local.json
sed -i "s,PROJECT_ID,$PROJECT_ID,g" ./apihub-api-deployment.local.json
sed -i "s,REGION,$REGION,g" ./apihub-api-deployment.local.json

# create deployment
curl -X POST "https://apihub.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/deployments?deploymentId=apigee-sample-unmanaged-v1-deployment" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  --data "@apihub-api-deployment.local.json"

# create api, version and spec in api hub
apigeecli apihub apis create -i "apigee-sample-api" -f apihub-api.local.json -r "$REGION" -o "$PROJECT_ID" -t $(gcloud auth print-access-token)
apigeecli apihub apis versions create -i "apigee-sample-api-v1" --api-id "apigee-sample-api" -f apihub-api-version.local.json -r "$REGION" -o "$PROJECT_ID" -t $(gcloud auth print-access-token)
apigeecli apihub apis versions specs create -i "apigee-sample-unmanaged-api-v1-spec" --api-id "apigee-sample-api" --version "apigee-sample-api-v1" -d "Apigee Sample Unmanaged API v1 Spec" -f "./oas.yaml" -r $REGION -o $PROJECT_ID -t $(gcloud auth print-access-token)

echo "🎊 Finished unmanaged Apigee sample API registration to API Hub!"
echo "🎊 Visit API Hub here to see results: https://console.cloud.google.com/apigee/api-hub/apis"