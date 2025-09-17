#!/bin/bash

echo "✅ Creating Python virtual env ..."
python -m venv .venv

echo "✅ Activating Python virtual env ..."
source .venv/bin/activate

echo "✅ Installing Python requirements ..."
pip install -r <(cat <<EOF
google-adk>=1.5.0,<2.0.0
google-cloud-aiplatform[adk,agent-engines]>=1.100.0,<2.0.0
python-dotenv>=1.1.1,<2.0.0
google-cloud-secret-manager>=2.24.0,<3.0.0
poetry>=2.2.0,<3.0.0
EOF
)
echo "✅ Installing apigee-go-gen tool ..."
rm -rf ~/.apigee-go-gen
curl -s https://apigee.github.io/apigee-go-gen/install | sh -s latest ~/.apigee-go-gen/bin

echo "✅ Installing apigeecli tool ..."
rm -rf ~/.apigeecli
curl -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh -


echo "✅ Installing integrationcli tool ..."
rm -rf ~/.integrationcli
curl -L https://raw.githubusercontent.com/GoogleCloudPlatform/application-integration-management-toolkit/main/downloadLatest.sh | sh -


