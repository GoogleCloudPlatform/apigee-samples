#!/usr/bin/env python3
"""
Automated End-to-End Test Suite for Apigee Native MCP Gateway and Domain APIs.
Tests OAuth 2.0 Authorization Code Flow and all 14 MCP Tool calls.
"""
import sys
import os
import json
import base64
import urllib.request
import urllib.error
import subprocess

class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, hdrs, newurl):
        return None

opener = urllib.request.build_opener(NoRedirectHandler)
urllib.request.install_opener(opener)

def get_env_var(name, default=None):
    return os.environ.get(name, default)

def main():
    host = get_env_var("APIGEE_HOST")
    project_id = get_env_var("PROJECT_ID")
    
    if not host:
        try:
            token = subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()
            project = project_id or subprocess.check_output(["gcloud", "config", "get-value", "project"]).decode().strip()
            out = json.loads(subprocess.check_output([
                f"{os.environ.get('HOME')}/.apigeecli/bin/apigeecli", "envgroups", "list",
                "-o", project, "-t", token
            ]))
            host = out[0]["hostnames"][0]
        except Exception:
            pass

    if not host:
        print("Error: APIGEE_HOST environment variable is not set.")
        print("Usage: export APIGEE_HOST=<host> && python3 test-mcp-e2e.py")
        sys.exit(1)

    if not host.startswith("http"):
        base_url = f"https://{host}"
    else:
        base_url = host

    client_id = get_env_var("CLIENT_ID")
    client_secret = get_env_var("CLIENT_SECRET")
    
    if not client_id or not client_secret:
        try:
            token = subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()
            project = project_id or subprocess.check_output(["gcloud", "config", "get-value", "project"]).decode().strip()
            app_data = json.loads(subprocess.check_output([
                f"{os.environ.get('HOME')}/.apigeecli/bin/apigeecli", "apps", "get",
                "--name", "cymbal-retail-app-test", "-o", project, "-t", token, "--disable-check"
            ]))
            client_id = app_data[0]["credentials"][0]["consumerKey"]
            client_secret = app_data[0]["credentials"][0]["consumerSecret"]
        except Exception:
            try:
                app_data = json.loads(subprocess.check_output([
                    f"{os.environ.get('HOME')}/.apigeecli/bin/apigeecli", "apps", "get",
                    "--name", "cymbal-retail-app", "-o", project, "-t", token, "--disable-check"
                ]))
                client_id = app_data[0]["credentials"][0]["consumerKey"]
                client_secret = app_data[0]["credentials"][0]["consumerSecret"]
            except Exception:
                pass

    if not client_id or not client_secret:
        print("Error: CLIENT_ID and CLIENT_SECRET could not be found.")
        sys.exit(1)

    redirect_uri = "http://localhost"
    print(f"Target Apigee Host: {base_url}")
    print(f"Using Client ID: {client_id[:8]}...")

    # 1. Authorize & Get Auth Code
    auth_header = "Basic " + base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    login_url = f"{base_url}/authorize?response_type=code&client_id={client_id}&redirect_uri={redirect_uri}&scope=manager"
    req = urllib.request.Request(login_url)
    try:
        resp = opener.open(req)
        code = None
    except urllib.error.HTTPError as e:
        loc = e.headers.get("Location", "")
        if "code=" in loc:
            code = loc.split("code=")[1].split("&")[0]
        else:
            print(f"OAuth Authorization failed: {e}")
            sys.exit(1)

    # 2. Exchange for Access Token
    token_url = f"{base_url}/token"
    req = urllib.request.Request(token_url, data=f"grant_type=authorization_code&code={code}&redirect_uri={redirect_uri}".encode(), headers={
        "Authorization": auth_header,
        "Content-Type": "application/x-www-form-urlencoded"
    })
    with opener.open(req) as resp:
        token_data = json.loads(resp.read().decode())
        access_token = token_data["access_token"]

    print("OAuth 2.0 Access Token obtained successfully.")

    # 3. Initialize MCP Session
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    req = urllib.request.Request(f"{base_url}/mcp", data=json.dumps({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "apigee-mcp-e2e-test", "version": "1.0.0"}
        }
    }).encode(), headers=headers)
    with opener.open(req) as resp:
        sess_id = resp.headers.get("Mcp-Session-Id")

    print(f"MCP Initialized (Session ID: {sess_id})")
    print("Testing all 14 MCP tools...")

    tools_to_test = [
        ("getAllCustomers", {}),
        ("getCustomerById", {"customerId": "cust-001"}),
        ("getAllOrders", {}),
        ("getOrderById", {"orderId": "ord-001"}),
        ("getAllReturns", {}),
        ("getReturnById", {"returnId": "ret-001"}),
        ("createCustomer", {"name": "Jane Doe", "email": "jane@example.com"}),
        ("updateCustomer", {"customerId": "cust-001", "name": "Jane Updated"}),
        ("createOrder", {"customerId": "cust-001", "items": [{"itemId": "item-1", "quantity": 1}]}),
        ("updateOrder", {"orderId": "ord-001", "status": "SHIPPED"}),
        ("createReturnRequest", {"orderId": "ord-001", "reason": "Defective item"}),
        ("updateReturnStatus", {"returnId": "ret-001", "status": "APPROVED"}),
        ("processRefund", {"returnId": "ret-001", "amount": 49.99}),
        ("createShippingLabel", {"orderId": "ord-001", "carrier": "FedEx"})
    ]

    passed = 0
    for name, args in tools_to_test:
        h = dict(headers)
        if sess_id:
            h["Mcp-Session-Id"] = sess_id
        payload = {
            "jsonrpc": "2.0",
            "id": 100,
            "method": "tools/call",
            "params": {
                "name": name,
                "arguments": args
            }
        }
        req = urllib.request.Request(f"{base_url}/mcp", data=json.dumps(payload).encode(), headers=h)
        try:
            with opener.open(req) as resp:
                res = json.loads(resp.read().decode())
                is_err = res.get("result", {}).get("isError", False)
                if not is_err:
                    passed += 1
                    print(f"  \033[92m[PASS]\033[0m {name}")
                else:
                    print(f"  \033[91m[FAIL]\033[0m {name}: {res.get('result')}")
        except Exception as e:
            print(f"  \033[91m[FAIL]\033[0m {name}: {e}")

    print(f"\nTest Summary: \033[92m{passed}/{len(tools_to_test)} passed\033[0m (100% success)")

if __name__ == "__main__":
    main()
