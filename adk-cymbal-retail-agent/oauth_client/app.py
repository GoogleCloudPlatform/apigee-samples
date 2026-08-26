# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import asyncio
import copy
import datetime
import os
import uuid
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
import httpx
from pydantic import BaseModel

# Load env variables from the root project directory if available
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

from google.adk.events.event import Event
from google.adk.events.event_actions import EventActions
from google.genai import types

# Initialize Agent Platform / Vertex AI Client
try:
    import agentplatform
    client_cls = agentplatform.Client
except ImportError:
    import vertexai
    client_cls = vertexai.Client

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("PROJECT_ID")
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION") or os.getenv("VERTEXAI_REGION") or "us-central1"
DISPLAY_NAME = os.getenv("AGENT_DISPLAY_NAME", "cymbal-retail-agent")

client = client_cls(
    project=PROJECT_ID,
    location=LOCATION
)

app = FastAPI(title="Cymbal Retail - Agent Identity 3LO Client Proxy")

# Allow CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global in-memory session state cache mapped by session_id
consent_sessions = {}

# Lazy-load the deployed agent engine resource name
REASONING_ENGINE_NAME = None


def get_deployed_engine_name():
    global REASONING_ENGINE_NAME
    if REASONING_ENGINE_NAME is None:
        matched_engines = []
        for a in client.agent_engines.list():
            if getattr(a.api_resource, "display_name", None) == DISPLAY_NAME:
                matched_engines.append(a.api_resource)
        if not matched_engines:
            raise RuntimeError(f"Deployed agent '{DISPLAY_NAME}' not found in project '{PROJECT_ID}', location '{LOCATION}'.")
        # Pick the most recently created/updated engine
        matched_engines.sort(key=lambda x: str(getattr(x, "update_time", "") or getattr(x, "create_time", "")), reverse=True)
        REASONING_ENGINE_NAME = matched_engines[0].name
    return REASONING_ENGINE_NAME


def extract_text_and_auth(event):
    """Extracts text content, error messages, and any adk_request_credential auth requirement from an agent event."""
    response_text = ""
    auth_request = None
    
    is_dict = isinstance(event, dict)
    
    # 0. Check for error fields on event
    error_msg = None
    if is_dict:
        error_msg = event.get("error_message") or event.get("errorMessage") or event.get("error")
    elif hasattr(event, "error_message"):
        error_msg = event.error_message
    elif hasattr(event, "error"):
        error_msg = event.error
        
    if error_msg:
        return f"⚠️ Agent Runtime Error: {error_msg}", None
    
    # 1. Check for function calls (Auth Request)
    function_calls = []
    if is_dict and "function_calls" in event:
        function_calls = event["function_calls"]
    elif is_dict or hasattr(event, "content"):
        content = event.get("content") if is_dict else getattr(event, "content", None)
        if content:
            parts = content.get("parts") if is_dict else getattr(content, "parts", [])
            for part in parts:
                call = part.get("function_call") if isinstance(part, dict) else getattr(part, "function_call", None)
                if call:
                    call_dict = call if isinstance(call, dict) else getattr(call, "__dict__", {})
                    if hasattr(call, "model_dump"):
                        call_dict = call.model_dump(mode="json")
                    function_calls.append(call_dict)
    elif hasattr(event, "get_function_calls"):
        try:
            function_calls = [
                call.model_dump(mode="json") if hasattr(call, "model_dump") else call
                for call in event.get_function_calls()
            ]
        except Exception:
            pass
            
    for call in function_calls:
        call_name = call.get("name") if isinstance(call, dict) else getattr(call, "name", None)
        call_id = call.get("id") if isinstance(call, dict) else getattr(call, "id", None)
        call_args = call.get("args") if isinstance(call, dict) else getattr(call, "args", {})
        
        if call_name == "adk_request_credential":
            auth_config = call_args.get("authConfig") or call_args.get("auth_config") or {}
            exchanged = auth_config.get("exchangedAuthCredential") or auth_config.get("exchanged_auth_credential") or {}
            raw = auth_config.get("rawAuthCredential") or auth_config.get("raw_auth_credential") or {}
            oauth2 = exchanged.get("oauth2") or raw.get("oauth2") or {}
            auth_uri = oauth2.get("authUri") or oauth2.get("auth_uri")
            nonce = oauth2.get("nonce")
            state = oauth2.get("state")
            invocation_id = call_args.get("functionCallId") or call_args.get("function_call_id")
            
            auth_request = {
                "pause": True,
                "call_id": call_id,
                "invocation_id": invocation_id,
                "auth_uri": auth_uri,
                "nonce": nonce,
                "state": state,
                "auth_config": auth_config
            }
            break
            
    # 2. Check for text content
    content = event.get("content") if is_dict else getattr(event, "content", None)
    if content:
        parts = content.get("parts") if is_dict else getattr(content, "parts", [])
        for part in parts:
            text = None
            if isinstance(part, dict):
                text = part.get("text")
            elif hasattr(part, "text"):
                text = part.text
            
            if text:
                response_text += text
                
    return response_text, auth_request


def extract_tool_calls(event):
    """Extracts non-auth tool invocations and responses for UI monitoring."""
    tool_calls = []
    is_dict = isinstance(event, dict)
    
    # 1. Extract function calls
    function_calls = []
    if is_dict and "function_calls" in event:
        function_calls = event["function_calls"]
    elif is_dict or hasattr(event, "content"):
        content = event.get("content") if is_dict else getattr(event, "content", None)
        if content:
            parts = content.get("parts") if is_dict else getattr(content, "parts", [])
            for part in parts:
                call = part.get("function_call") if isinstance(part, dict) else getattr(part, "function_call", None)
                if call:
                    call_dict = call if isinstance(call, dict) else getattr(call, "__dict__", {})
                    if hasattr(call, "model_dump"):
                        call_dict = call.model_dump(mode="json")
                    function_calls.append(call_dict)
    elif hasattr(event, "get_function_calls"):
        try:
            function_calls = [
                call.model_dump(mode="json") if hasattr(call, "model_dump") else call
                for call in event.get_function_calls()
            ]
        except Exception:
            pass
            
    for call in function_calls:
        name = call.get("name") if isinstance(call, dict) else getattr(call, "name", None)
        call_id = call.get("id") if isinstance(call, dict) else getattr(call, "id", None)
        if name and name != "adk_request_credential":
            tool_calls.append({
                "type": "call",
                "name": name,
                "id": call_id
            })
            
    # 2. Extract function responses
    function_responses = []
    if is_dict and "function_responses" in event:
        function_responses = event["function_responses"]
    elif is_dict or hasattr(event, "content"):
        content = event.get("content") if is_dict else getattr(event, "content", None)
        if content:
            parts = content.get("parts") if is_dict else getattr(content, "parts", [])
            for part in parts:
                resp = part.get("function_response") if isinstance(part, dict) else getattr(part, "function_response", None)
                if resp:
                    resp_dict = resp if isinstance(resp, dict) else getattr(resp, "__dict__", {})
                    if hasattr(resp, "model_dump"):
                        resp_dict = resp.model_dump(mode="json")
                    function_responses.append(resp_dict)
    elif hasattr(event, "get_function_responses"):
        try:
            function_responses = [
                resp.model_dump(mode="json") if hasattr(resp, "model_dump") else resp
                for resp in event.get_function_responses()
            ]
        except Exception:
            pass
            
    for resp in function_responses:
        name = resp.get("name") if isinstance(resp, dict) else getattr(resp, "name", None)
        call_id = resp.get("id") if isinstance(resp, dict) else getattr(resp, "id", None)
        if name and name != "adk_request_credential":
            tool_calls.append({
                "type": "response",
                "name": name,
                "id": call_id
            })
            
    return tool_calls


def extract_function_response_text(event):
    """Extracts formatted text from non-auth function responses as a fallback when the model doesn't yield text."""
    text_content = ""
    is_dict = isinstance(event, dict)
    
    parts = []
    if is_dict and "content" in event and isinstance(event["content"], dict):
        parts = event["content"].get("parts", [])
    elif hasattr(event, "content") and getattr(event, "content", None):
        parts = getattr(event.content, "parts", [])
        
    for part in parts:
        resp = part.get("function_response") if isinstance(part, dict) else getattr(part, "function_response", None)
        if resp:
            resp_dict = resp if isinstance(resp, dict) else getattr(resp, "__dict__", {})
            if hasattr(resp, "model_dump"):
                resp_dict = resp.model_dump(mode="json")
            name = resp_dict.get("name")
            if name in ("adk_request_credential", "transfer_to_agent"):
                continue
            r_data = resp_dict.get("response") or {}
            if isinstance(r_data, dict):
                content_list = r_data.get("content", [])
                if isinstance(content_list, list):
                    for item in content_list:
                        if isinstance(item, dict) and item.get("type") == "text":
                            text_content += item.get("text", "") + "\n"
                elif "result" in r_data and r_data["result"] is not None:
                    text_content += str(r_data["result"]) + "\n"
    return text_content.strip()


class SessionRequest(BaseModel):
    user_id: Optional[str] = "customer@cymbal-retail.com"


class ChatRequest(BaseModel):
    session_id: str
    message: str
    user_id: Optional[str] = "customer@cymbal-retail.com"


class ResumeRequest(BaseModel):
    session_id: str
    call_id: str
    invocation_id: Optional[str] = None
    auth_uri: Optional[str] = None
    user_id: Optional[str] = "customer@cymbal-retail.com"
    code: Optional[str] = None
    state: Optional[str] = None
    auth_response_uri: Optional[str] = None


@app.post("/api/session")
async def create_session(request: Optional[SessionRequest] = None):
    """Creates a new Reasoning Engine session on GEAP."""
    try:
        user_id = request.user_id if request and request.user_id else "customer@cymbal-retail.com"
        engine_name = get_deployed_engine_name()
        # Extract the reasoning engine resource ID (e.g. 7413991512930779136)
        engine_id = engine_name.split("/")[-1]
        
        session_id = str(uuid.uuid4())
        
        # Create session remotely
        api_response = client.agent_engines.sessions.create(
            name=f"reasoningEngines/{engine_id}",
            user_id=user_id,
            config={"session_id": session_id}
        )
        
        remote_session_name = ""
        if hasattr(api_response, "response") and api_response.response and hasattr(api_response.response, "name"):
            remote_session_name = api_response.response.name
        elif hasattr(api_response, "name"):
            remote_session_name = api_response.name

        global consent_sessions
        consent_sessions[session_id] = {
            "user_id": user_id,
            "created_at": datetime.datetime.now().isoformat()
        }
        
        response = JSONResponse(content={"session_id": session_id, "remote_session_name": str(remote_session_name)})
        response.set_cookie(key="session_id", value=session_id, path="/", samesite="lax")
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create session: {e}")


@app.post("/api/chat")
async def chat(request: ChatRequest):
    """Sends a chat message to the Reasoning Engine and checks for OAuth consent requirements."""
    max_attempts = 3
    for attempt in range(max_attempts):
        try:
            engine_name = get_deployed_engine_name()
            remote_app = client.agent_engines.get(name=engine_name)
            
            user_id = request.user_id or "customer@cymbal-retail.com"
            response_text = ""
            fallback_tool_text = ""
            auth_request = None
            tool_calls = []
            
            current_payload = request.message
            max_turn_passes = 4
            
            for pass_idx in range(max_turn_passes):
                events_in_pass = 0
                has_text_in_pass = False
                
                for event in remote_app.stream_query(
                    user_id=user_id,
                    session_id=request.session_id,
                    message=current_payload
                ):
                    events_in_pass += 1
                    print(f"[DEBUG CHAT EVENT] Pass {pass_idx+1} Raw Event: {event}")
                    text, auth = extract_text_and_auth(event)
                    if text:
                        has_text_in_pass = True
                        response_text += text
                    fallback_text = extract_function_response_text(event)
                    if fallback_text:
                        fallback_tool_text += fallback_text + "\n"
                    tool_calls.extend(extract_tool_calls(event))
                    if auth:
                        auth_request = auth
                
                if auth_request:
                    global consent_sessions
                    if request.session_id not in consent_sessions:
                        consent_sessions[request.session_id] = {}
                    consent_sessions[request.session_id].update({
                        "call_id": auth_request["call_id"],
                        "invocation_id": auth_request["invocation_id"],
                        "auth_uri": auth_request["auth_uri"],
                        "nonce": auth_request["nonce"],
                        "consent_nonce": auth_request["nonce"],
                        "state": auth_request.get("state"),
                        "auth_config": auth_request["auth_config"],
                        "user_id": user_id,
                        "completed": False
                    })
                    auth_request["tool_calls"] = tool_calls
                    return auth_request

                # If text was produced or no events happened at all, the turn is complete
                if has_text_in_pass or events_in_pass == 0:
                    break

                # If internal events happened (e.g. transfer_to_agent) without text output,
                # auto-continue passing the user's original message to the newly active agent
                print(f"[DEBUG CHAT] Pass {pass_idx+1} had {events_in_pass} internal events without text; auto-continuing...")
                current_payload = request.message or "Please proceed with the request."
            
            final_response = response_text.strip() or fallback_tool_text.strip()
            return {"pause": False, "response": final_response, "tool_calls": tool_calls}
            
        except Exception as e:
            err_str = str(e)
            if attempt < max_attempts - 1 and ("FAILED_PRECONDITION" in err_str or "Reasoning Engine Execution failed" in err_str):
                print(f"[DEBUG CHAT] Transient Reasoning Engine error on attempt {attempt+1}, retrying in 1.0s: {err_str}")
                await asyncio.sleep(1.0)
                continue
            raise HTTPException(status_code=500, detail=str(e))



@app.post("/api/resume")
async def resume(request: ResumeRequest):
    """Resumes agent conversation after Agent Identity 3LO credentials finalization."""
    try:
        # Initial async delay to allow credential replication across Google Cloud
        # await asyncio.sleep(2.0)
        engine_name = get_deployed_engine_name()
        
        # Load original authConfig from the in-memory consent_sessions cache
        global consent_sessions
        session_data = consent_sessions.get(request.session_id) or {}
        original_auth_config = session_data.get("auth_config") or {}
            
        auth_response_config = copy.deepcopy(original_auth_config)
        
        # Create the FunctionResponse Content matching the adk_request_credential call
        call_id = request.call_id or session_data.get("call_id")
        auth_content = types.Content(
            role="user",
            parts=[
                types.Part(
                    function_response=types.FunctionResponse(
                        name="adk_request_credential",
                        id=call_id,
                        response=auth_response_config
                    )
                )
            ]
        )
        
        user_id = request.user_id or session_data.get("user_id") or "customer@cymbal-retail.com"
        remote_app = client.agent_engines.get(name=engine_name)
        
        # Invoke stream_query with retry in case of transient replication delay
        response_text = ""
        fallback_tool_text = ""
        auth_request = None
        tool_calls = []
        max_attempts = 3
        
        for attempt in range(max_attempts):
            try:
                response_text = ""
                fallback_tool_text = ""
                auth_request = None
                tool_calls = []
                
                for event in remote_app.stream_query(
                    user_id=user_id,
                    session_id=request.session_id,
                    message=auth_content.model_dump(mode="json", exclude_none=True)
                ):
                    print(f"[DEBUG RESUME EVENT] Raw Event: {event}")
                    text, auth = extract_text_and_auth(event)
                    response_text += text
                    fallback_text = extract_function_response_text(event)
                    if fallback_text:
                        fallback_tool_text += fallback_text + "\n"
                    tool_calls.extend(extract_tool_calls(event))
                    if auth:
                        auth_request = auth
                break
            except Exception as e:
                err_str = str(e)
                if attempt < max_attempts - 1 and ("FAILED_PRECONDITION" in err_str or "Reasoning Engine Execution failed" in err_str):
                    print(f"[DEBUG RESUME] Transient FAILED_PRECONDITION encountered on attempt {attempt+1}, retrying in 1.0s...")
                    await asyncio.sleep(1.0)
                    continue
                raise
                
        if auth_request:
            consent_sessions[request.session_id].update({
                "call_id": auth_request["call_id"],
                "invocation_id": auth_request["invocation_id"],
                "auth_uri": auth_request["auth_uri"],
                "nonce": auth_request["nonce"],
                "consent_nonce": auth_request["nonce"],
                "state": auth_request.get("state"),
                "auth_config": auth_request["auth_config"],
                "user_id": user_id,
                "completed": False
            })
            auth_request["tool_calls"] = tool_calls
            return auth_request

        # If the resume turn did not yield a synthesized text response (e.g. engine yielded 0 events
        # or only an unexecuted tool call), automatically query the session to continue execution and fetch the tool results.
        if not response_text.strip() and not fallback_tool_text.strip():
            print("[DEBUG RESUME] No text response received from resume; continuing session execution...")
            for cont_event in remote_app.stream_query(
                user_id=user_id,
                session_id=request.session_id,
                message="Please proceed with the request."
            ):
                print(f"[DEBUG RESUME CONTINUATION EVENT] Raw Event: {cont_event}")
                text, auth = extract_text_and_auth(cont_event)
                response_text += text
                fallback_text = extract_function_response_text(cont_event)
                if fallback_text:
                    fallback_tool_text += fallback_text + "\n"
                tool_calls.extend(extract_tool_calls(cont_event))
                if auth:
                    auth_request = auth
                    consent_sessions[request.session_id].update({
                        "call_id": auth_request["call_id"],
                        "invocation_id": auth_request["invocation_id"],
                        "auth_uri": auth_request["auth_uri"],
                        "nonce": auth_request["nonce"],
                        "consent_nonce": auth_request["nonce"],
                        "state": auth_request.get("state"),
                        "auth_config": auth_request["auth_config"],
                        "user_id": user_id,
                        "completed": False
                    })
                    auth_request["tool_calls"] = tool_calls
                    return auth_request
            
        final_response = response_text.strip() or fallback_tool_text.strip()
        return {"pause": False, "response": final_response, "tool_calls": tool_calls}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/check_auth")
async def check_auth(session_id: str = Query(...)):
    """Checks if the validation callback has completed for the given session_id."""
    global consent_sessions
    session_data = consent_sessions.get(session_id)
    if session_data and session_data.get("completed"):
        callback_url = session_data.get("callback_url", "")
        session_data["completed"] = False
        return {"completed": True, "callback_url": callback_url}
    return {"completed": False}


# Serve index.html at the root
@app.get("/")
async def get_index():
    return FileResponse(os.path.join(os.path.dirname(__file__), "static", "index.html"))


# Serve the OAuth validation callback endpoint (supporting both /callback and /validateUserId)
@app.api_route("/callback", methods=["GET"])
@app.api_route("/validateUserId", methods=["GET"])
async def oauth_callback(
    request: Request,
    code: Optional[str] = None,
    state: Optional[str] = None,
    user_id_validation_state: Optional[str] = None,
    connector_name: Optional[str] = None,
    auth_provider_name: Optional[str] = None,
    uuid: Optional[str] = None,
):
    """OAuth callback validation page that finalizes credentials with Google Agent Identity API."""
    global consent_sessions
    success = False
    err_detail = ""
    
    # 1. Resolve session data
    session_id = request.cookies.get("session_id")
    session_data = consent_sessions.get(session_id) if session_id else None
    
    if not session_data and uuid and uuid in consent_sessions:
        session_id = uuid
        session_data = consent_sessions.get(session_id)
        
    if not session_data and state:
        for s_id, s_data in consent_sessions.items():
            if s_data.get("state") == state:
                session_id = s_id
                session_data = s_data
                break
                
    if not session_data and len(consent_sessions) == 1:
        session_id = next(iter(consent_sessions.keys()))
        session_data = consent_sessions[session_id]
    elif not session_data and consent_sessions:
        pending = [
            (s_id, s_data) for s_id, s_data in consent_sessions.items()
            if (s_data.get("nonce") or s_data.get("consent_nonce")) and not s_data.get("completed")
        ]
        if pending:
            session_id, session_data = pending[-1]

    # 2. Check if this is an Agent Identity 3LO v2 callback
    resolved_auth_provider = auth_provider_name or connector_name
    
    if resolved_auth_provider or user_id_validation_state:
        if not resolved_auth_provider:
            default_auth_provider = os.getenv("AUTH_PROVIDER_NAME", "cymbal-idp")
            resolved_auth_provider = f"projects/{PROJECT_ID}/locations/{LOCATION}/authProviders/{default_auth_provider}"
            
        if not resolved_auth_provider.startswith("projects/"):
            resolved_auth_provider = f"projects/{PROJECT_ID}/locations/{LOCATION}/authProviders/{resolved_auth_provider}"
            
        auth_provider_path = resolved_auth_provider.lstrip("/").replace("/connectors/", "/authProviders/")
        
        if session_data:
            session_data["callback_url"] = str(request.url)
            consent_nonce = session_data.get("nonce") or session_data.get("consent_nonce")
            consent_user_id = session_data.get("user_id", "customer@cymbal-retail.com")
            
            payload = {
                "userId": consent_user_id,
                "userIdValidationState": user_id_validation_state,
                "consentNonce": consent_nonce
            }
            
            finalize_url = f"https://agentidentitycredentials.googleapis.com/v1alpha/{auth_provider_path}/credentials:finalize"
            print(f"[DEBUG CALLBACK] Calling FinalizeCredentials on: {finalize_url}")
            print(f"[DEBUG CALLBACK] Payload: {payload}")
            
            try:
                async with httpx.AsyncClient(timeout=30.0) as http_client:
                    resp = await http_client.post(finalize_url, json=payload)
                    print(f"[DEBUG CALLBACK] FinalizeCredentials Status: {resp.status_code}, Response: {resp.text}")
                    resp.raise_for_status()
                    print("[DEBUG CALLBACK] FinalizeCredentials completed successfully!")
                    success = True
                    session_data["completed"] = True
            except Exception as e:
                err_detail = e.response.text if hasattr(e, "response") else str(e)
                print(f"[DEBUG CALLBACK] Error calling FinalizeCredentials: {err_detail}")
        else:
            err_detail = f"No active pending session found for session_id '{session_id}'."
            print(f"[DEBUG CALLBACK] {err_detail}")
    elif code or state:
        # Direct OAuth fallback
        if session_data:
            session_data["callback_url"] = str(request.url)
            success = True
            session_data["completed"] = True
        else:
            err_detail = "No active pending session found for direct OAuth callback."
    else:
        err_detail = "Missing required OAuth callback query parameters."

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Authentication Status</title>
        <style>
            body {{ font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif; background: #12131a; color: #e1e3eb; text-align: center; padding: 3rem 1.5rem; margin: 0; }}
            .card {{ background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08); padding: 2rem; border-radius: 12px; display: inline-block; max-width: 440px; box-shadow: 0 8px 32px rgba(0,0,0,0.3); }}
            h3 {{ color: { "#4caf50" if success else "#f44336" }; margin-top: 0; }}
            .btn-close {{ margin-top: 1.2rem; background: #1a73e8; color: white; border: none; padding: 0.6rem 1.4rem; border-radius: 6px; cursor: pointer; font-size: 0.95rem; font-weight: 500; }}
            .btn-close:hover {{ background: #1557b0; }}
        </style>
    </head>
    <body>
        <div class="card">
            <h3>{"✓ Login Successful!" if success else "✗ Verification Failed"}</h3>
            <p>{"You can return to the chat window. Click the button below to close this window." if success else f"Verification failed: {err_detail}"}</p>
            <button onclick="window.close()" class="btn-close">Close Window</button>
        </div>
        <script>
            if ({ "true" if success else "false" }) {{
                try {{
                    if (window.opener && !window.opener.closed) {{
                        window.opener.postMessage({{
                            type: "oauth_callback",
                            url: window.location.href
                        }}, "*");
                    }}
                }} catch (e) {{}}
            }}
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


# Mount static folder for CSS/JS assets
app.mount("/static", StaticFiles(directory=os.path.join(os.path.dirname(__file__), "static")), name="static")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="127.0.0.1", port=9000, reload=True)

