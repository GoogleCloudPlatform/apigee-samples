#!/bin/bash

set -e


if [ -z "${GCP_USER_ID}" ]; then
    echo "❌ Error: The required environment variable GCP_USER_ID is not set." >&2
    exit 1
fi

if [ -z "${GCP_USER_PASSWORD}" ]; then
    echo "❌ Error: The required environment variable GCP_USER_PASSWORD is not set." >&2
    exit 1
fi

if [ -z "${PROJECT_ID}" ]; then
    echo "❌ Error: The required environment variable PROJECT_ID is not set." >&2
    exit 1
fi

VENV_DIR="$HOME/.venv"

echo "✅ Checking for Python virtual environment at $VENV_DIR..."

if [ ! -d "$VENV_DIR" ]; then
    echo "ℹ️ Virtual environment not found. Creating it now..."
    python3 -m venv "$VENV_DIR"
    echo "✅ Virtual environment created."
fi

echo "✅ Activating virtual environment..."
source "$VENV_DIR/bin/activate"

echo "✅ Installing Playwright and its browsers..."
pip install playwright
playwright install chrome

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PYTHON_SCRIPT="$SCRIPT_DIR/oauth-setup.py"

echo "✅ Executing the Python script: $PYTHON_SCRIPT"

python3 "$PYTHON_SCRIPT" \
    --username="${GCP_USER_ID}" \
    --password="${GCP_USER_PASSWORD}" \
    --project-id="${PROJECT_ID}" \
    --branding-app-name="cymbal-retail" \
    --oauth-client-name="cymbal-agent-app" \
    --redirect-uris \
    "http://localhost:8000/dev-ui/" \
    "http://127.0.0.1:8000/dev-ui/" \
    "https://console.cloud.google.com/connectors/oauth?project=${PROJECT_ID}"

echo "✅ OAuth application configured ..."
