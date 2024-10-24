#!/bin/bash

if [ -z "$PROJECT_ID" ]; then
  echo "No PROJECT_ID variable set"
  exit
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit
fi


TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Undeploying proxy"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="custom-routing").revision' -r)
apigeecli apis undeploy --name custom-routing --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT_ID" --token "$TOKEN"

echo "Deleting proxy"
apigeecli apis delete --name custom-routing --org "$PROJECT_ID" --token "$TOKEN"

echo "Deleting KVMs"
apigeecli kvms delete --org "$PROJECT_ID" -p custom-routing --name routing-rules --token "$TOKEN"

echo "DONE"