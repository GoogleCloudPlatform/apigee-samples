# Apigee AI Agents Workshop — Playwright End-to-End Test Suite

Automated browser + API end-to-end validation suite for the **Apigee AI Agents Workshop (`enbl080-apigee-ai-agents-workshop`)**.

It drives real **Google Cloud Console (Apigee API Hub, Apigee Proxy/Product UI, Custom Analytics Reports, Gemini Enterprise)**, **Google ADK Web UI** (including live 3-legged OAuth popup handshakes on `http://127.0.0.1:8000/dev-ui/`), and the **Go GenAI Analytics Dashboard (`http://127.0.0.1:8080`)**, verifying all **5 workshop tasks** and all **7 Activity Tracking assessments (`100/100`)**.

---

## Directory Contents

| File | Purpose |
| :--- | :--- |
| `run_workshop_e2e.py` | End-to-end CLI runner executing Tasks 1–5, capturing UI screenshots, and evaluating Qwiklabs Ruby assessments |
| `browser_sso.py` | Launches isolated headless Chrome CDP daemon and signs into Google Cloud Console via Qwiklabs SSO |
| `mcp_wizard.py` | Drives the 3-step **API Hub -> Configure MCP tools** wizard in both Create Mode (Task 2A) and Edit Mode (Task 3A), plus OpenAPI spec sync safeguard |
| `adk_ui.py` | Manages local `uv run adk web` server (`127.0.0.1:8000`) and drives multi-turn prompts + 3-legged OAuth popups |
| `requirements.txt` | Python package dependency (`playwright>=1.50.0`) |

---

## Quick Start

```bash
python3 -m venv .venv_e2e
source .venv_e2e/bin/activate
pip install -r requirements.txt
playwright install chromium

# Authenticate gcloud as the lab student (or target project user)
gcloud auth login
gcloud auth application-default login

# Run complete Tasks 1-5 E2E validation + all 7 Qwiklabs assessments
export QWIKLABS_PASSWORD="<student-password>"
python3 run_workshop_e2e.py \
  --project "<qwiklabs-project-id>" \
  --region "<provisioned-region>" \
  --student-email "<student-email>" \
  --sso-url "<qwiklabs-google-sso-url>" \
  --assessments-dir "/path/to/enbl080-apigee-ai-agents-workshop/assessments" \
  --output-dir "./artifacts_e2e"
```
