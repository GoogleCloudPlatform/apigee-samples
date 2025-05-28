#!/bin/bash
export PROJECT="<PROJECT_ID_TO_SET>"
export REGION="<REGION_TO_SET>" # e.g., us-central1
export APIGEE_ENV="<APIGEE_ENV_TO_SET>" # e.g., eval
export APIGEE_HOST="<APIGEE_HOST_TO_SET>" # e.g., your-org-eval.apigee.net
export SA_EMAIL="<SA_EMAIL_TO_SET>" # e.g., apigee-runtime-sa@<PROJECT_ID_TO_SET>.iam.gserviceaccount.com

echo "Environment variables configured. Ensure values above are correctly set."
echo "PROJECT: $PROJECT"
echo "REGION: $REGION"
echo "APIGEE_ENV: $APIGEE_ENV"
echo "APIGEE_HOST: $APIGEE_HOST"
echo "SA_EMAIL: $SA_EMAIL"