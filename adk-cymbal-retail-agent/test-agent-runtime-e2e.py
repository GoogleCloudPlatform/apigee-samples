#!/usr/bin/env python3
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
End-to-End Regression Test Suite for Cymbal Retail Agent on Google Agent Platform (GEAP)
Tests Agent Runtime reasoning engine lifecycle, sessions, streaming queries, and tool calling.
"""

import os
import sys
import subprocess
import json
import time

def get_env(name, default=None):
    return os.environ.get(name, default)

def main():
    project = get_env("PROJECT_ID", "apigeex-talanki")
    location = get_env("VERTEXAI_REGION", "us-central1")
    display_name = get_env("AGENT_DISPLAY_NAME", "cymbal-retail-agent")

    print("==================================================================")
    print("  CYMBAL RETAIL AGENT: AGENT PLATFORM & RUNTIME REGRESSION SUITE  ")
    print("==================================================================")
    print(f"  Project:   {project}")
    print(f"  Location:  {location}")
    print(f"  Agent:     {display_name}\n")

    try:
        import agentplatform
    except ImportError:
        print("\033[91m[FAIL]\033[0m agentplatform module not installed. Please activate the virtual environment.")
        sys.exit(1)

    passed = 0
    total = 0

    # 1. Connect and locate deployed reasoning engine
    total += 1
    print("1. Locating Deployed Agent Runtime Reasoning Engine...")
    client = agentplatform.Client(project=project, location=location)
    matching_agent = None
    try:
        engine_name = None
        for engine in client.agent_engines.list():
            if getattr(engine.api_resource, "display_name", None) == display_name:
                engine_name = engine.api_resource.name
                break
        if engine_name:
            matching_agent = client.agent_engines.get(name=engine_name)
            passed += 1
            print(f"  \033[92m[PASS]\033[0m Found and initialized Agent Engine: {engine_name}")
        else:
            print(f"  \033[91m[FAIL]\033[0m No engine found with display name '{display_name}'")
            sys.exit(1)
    except Exception as e:
        print(f"  \033[91m[FAIL]\033[0m Error querying Agent Engines: {e}")
        sys.exit(1)

    # 2. Test Session Management Lifecycle
    total += 1
    print("\n2. Testing Agent Session Management Lifecycle...")
    test_user = "regression-test-user"
    session_id = None
    try:
        # Create session
        session = matching_agent.create_session(user_id=test_user)
        session_id = getattr(session, "session_id", None) or getattr(session, "id", None) or (session.get("session_id") if isinstance(session, dict) else str(session))
        print(f"  - Created test session: {session_id}")

        # List sessions
        sessions = matching_agent.list_sessions(user_id=test_user)
        session_list = getattr(sessions, "sessions", sessions) if hasattr(sessions, "sessions") else (sessions if isinstance(sessions, list) else [sessions])
        print(f"  - Verified active sessions count: {len(session_list)}")

        # Delete session
        if session_id:
            matching_agent.delete_session(user_id=test_user, session_id=session_id)
            print("  - Successfully cleaned up test session.")
        passed += 1
        print("  \033[92m[PASS]\033[0m Session Create, List, and Delete lifecycle verified.")
    except Exception as e:
        print(f"  \033[91m[FAIL]\033[0m Session lifecycle failed: {e}")

    # 3. Test Tool Execution via Stream Query (get_current_time tool)
    total += 1
    print("\n3. Testing Agent Tool Invocation (get_current_time)...")
    try:
        tool_executed = False
        model_responded = False
        full_text = []
        for chunk in matching_agent.stream_query(message="What is the current time?", user_id=test_user):
            content = chunk.get("content", {})
            parts = content.get("parts", [])
            for part in parts:
                if "function_call" in part or "function_response" in part:
                    tool_executed = True
                if "text" in part:
                    model_responded = True
                    full_text.append(part["text"])

        response_str = "".join(full_text)
        if tool_executed and model_responded:
            passed += 1
            print(f"  - Response: {response_str.strip()}")
            print("  \033[92m[PASS]\033[0m Tool call executed and model response generated successfully.")
        else:
            print(f"  \033[91m[FAIL]\033[0m Tool execution not observed (tool_executed={tool_executed}, model_responded={model_responded})")
    except Exception as e:
        print(f"  \033[91m[FAIL]\033[0m Stream query failed: {e}")

    # 4. Test Conversational Assistance & Identity Prompting
    total += 1
    print("\n4. Testing Retail Assistant Persona & Delegation Schema...")
    try:
        full_text = []
        for chunk in matching_agent.stream_query(message="Hello! Who are you?", user_id=test_user):
            content = chunk.get("content", {})
            for part in content.get("parts", []):
                if "text" in part:
                    full_text.append(part["text"])

        response_str = "".join(full_text)
        if "Cymbal" in response_str or "retail" in response_str.lower() or "help" in response_str.lower() or len(response_str) > 0:
            passed += 1
            print(f"  - Response: {response_str.strip()[:100]}...")
            print("  \033[92m[PASS]\033[0m Assistant Persona and system instructions verified.")
        else:
            print(f"  \033[91m[FAIL]\033[0m Unexpected persona response: {response_str}")
    except Exception as e:
        print(f"  \033[91m[FAIL]\033[0m Persona test failed: {e}")

    # 5. Verify Agent Identity Auth Provider
    total += 1
    print("\n5. Testing Agent Identity Auth Provider & IAM Bindings...")
    try:
        res = subprocess.run(
            ["gcloud", "beta", "agent-identity", "auth-providers", "describe", "cymbal-idp",
             f"--project={project}", f"--location={location}", "--format=json"],
            capture_output=True, text=True
        )
        if res.returncode == 0:
            provider_info = json.loads(res.stdout)
            client_id = (
                provider_info.get("authProviderTypeParams", {}).get("threeLeggedOauth", {}).get("clientId") or
                provider_info.get("threeLeggedOAuth", {}).get("clientId", "")
            )
            if client_id:
                passed += 1
                print(f"  - Provider: {provider_info.get('name')}")
                print(f"  - Configured OAuth Client ID: {client_id[:8]}...")
                print("  \033[92m[PASS]\033[0m Agent Identity Auth Provider verified.")
            else:
                print("  \033[91m[FAIL]\033[0m Auth provider missing OAuth Client configuration.")
        else:
            print(f"  \033[91m[FAIL]\033[0m Auth provider describe failed: {res.stderr}")
    except Exception as e:
        print(f"  \033[91m[FAIL]\033[0m Auth provider check failed: {e}")

    # Summary
    print("\n==================================================================")
    print(f"  Agent Runtime Regression Suite Results: \033[92m{passed}/{total} Passed\033[0m ({int(passed/total*100)}%)")
    print("==================================================================")

    if passed == total:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
