#!/bin/bash

echo "✅ Installing apigeecli tool ..."
rm -rf ~/.apigeecli
curl -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh -

echo "✅ Installing dependencies..."
pushd "cymbal-retail-agent"
uv sync
popd