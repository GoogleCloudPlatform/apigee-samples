echo "💻 Deploying Apigee proxy and portal catalog entry..."

# copy oas for apigee proxy
cp oas.yaml oas.local.yaml

# create apigee proxy based on spec
apigeecli apis create openapi -n "apihub-portal-publish" -f . --oas-name "oas.local.yaml" -p "/v1/samples/apihub-portal-publish" --add-cors=true -o "$PROJECT_ID" --env "$APIGEE_ENV" --wait=true -t $(gcloud auth print-access-token)

# now replace oas server with apigee
sed -i "s,mocktarget.apigee.net,$APIGEE_HOST,g" ./oas.local.yaml
sed -i "s,/:,/v1/samples/apihub-portal-publish:,g" ./oas.local.yaml
sed -i "s,/ip:,/v1/samples/apihub-portal-publish/ip:,g" ./oas.local.yaml
sed -i "s,/json:,/v1/samples/apihub-portal-publish/json:,g" ./oas.local.yaml

# create apigee product
apigeecli products create --name "apihub-portal-product" --display-name "API Hub Apigee Product" -p "apihub-portal-publish" --envs "dev" --approval "auto" --attrs "access=public" -o "$PROJECT_ID" -t $(gcloud auth print-access-token)

# get portal id from url
export APIGEE_PORTAL_ID=$(echo "${APIGEE_PORTAL_URL/.apigee.io/}")

# create portal doc
export CATALOG_ID=$(apigeecli apidocs create --allow-anon "true" --api-product "apihub-portal-product" --desc "Apigee Sample Product" --image-url "https://storage.googleapis.com/gweb-developer-goog-blog-assets/images/Banner-Apigee-API-Hub.original.png" -p "true" --require-callback-url "false" -l "Apigee Sample Product" -s "$APIGEE_PORTAL_ID" -o "$PROJECT_ID" -t $(gcloud auth print-access-token) | jq --raw-output ".data.id")

# update portal documentation
apigeecli apidocs documentation update -i "$CATALOG_ID" -n "Apigee Sample Product" -p "./oas.local.yaml" -s "$APIGEE_PORTAL_ID" -o "$PROJECT_ID" -t $(gcloud auth print-access-token)

echo "💻 Registering Apigee managed API to API Hub..."

sed -i "s,mocktarget.apigee.net/help,$APIGEE_PORTAL_URL/docs/apihub-portal-product/1,g" ./apihub-api.local.json
sed -i "s,mocktarget.apigee.net/help,$APIGEE_PORTAL_URL/docs/apihub-portal-product/1,g" ./apihub-api-version.local.json
sed -i "s,mocktarget.apigee.net/help,$APIGEE_PORTAL_URL/docs/apihub-portal-product/1,g" ./apihub-api-deployment.local.json
sed -i "s,mocktarget.apigee.net,$APIGEE_HOST/v1/samples/apihub-portal-publish,g" ./apihub-api-deployment.local.json
sed -i "s,unmanaged,apigee,g" ./apihub-api-deployment.local.json
sed -i "s,Unmanaged,Apigee,g" ./apihub-api-deployment.local.json
sed -i "s,test,prod,g" ./apihub-api-deployment.local.json
sed -i "s,Test,Production,g" ./apihub-api-deployment.local.json
sed -i "s.-v1-deployment\".-v1-deployment\", \"projects/$PROJECT_ID/locations/$REGION/deployments/apigee-sample-managed-v1-deployment\".g" ./apihub-api-version.local.json
sed -i "s,develop,prod,g" ./apihub-api-version.local.json
sed -i "s,Develop,Production,g" ./apihub-api-version.local.json

# create managed deployment
curl -X POST "https://apihub.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/deployments?deploymentId=apigee-sample-managed-v1-deployment" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  --data "@apihub-api-deployment.local.json"

# create api version spec for apigee
apigeecli apihub apis versions specs create -i "apigee-sample-managed-api-v1-spec" --api-id "apigee-sample-api" --version "apigee-sample-api-v1" -d "Apigee Sample Managed API v1 Spec" -f "./oas.local.yaml" -r $REGION -o $PROJECT_ID -t $(gcloud auth print-access-token)
apigeecli apihub apis versions update --api-id "apigee-sample-api" -i "apigee-sample-api-v1" -f apihub-api-version.local.json -r "$REGION" -o "$PROJECT_ID" -t $(gcloud auth print-access-token)
apigeecli apihub apis update -i "apigee-sample-api" -f apihub-api.local.json -r "$REGION" -o "$PROJECT_ID" -t $(gcloud auth print-access-token)

echo "🎊 Finished with managed API deployment and API Hub registration!"
echo "🎊 Visit API Hub here to see results: https://console.cloud.google.com/apigee/api-hub/apis"