import datetime
import os
import uuid
from typing import Optional


from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import vertexai
from dotenv import load_dotenv
from pathlib import Path

# Load env variables from the root project directory
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(dotenv_path=env_path)
from google.adk.events.event import Event
from google.adk.events.event_actions import EventActions
from google.genai import types

app = FastAPI(title="ADK 3LO Custom Client Proxy")

# Allow CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION")
DISPLAY_NAME = "cymbal-retail-agent"

# Initialize Vertex AI Client
client = vertexai.Client(
    project=PROJECT_ID,
    location=LOCATION
)

# Global in-memory session state cache mapped by session_id
consent_sessions = {}

# Lazy-load the deployed agent engine resource name
REASONING_ENGINE_NAME = None

def get_deployed_engine_name():
    global REASONING_ENGINE_NAME
    if REASONING_ENGINE_NAME is None:
        for a in client.agent_engines.list():
            if a.api_resource.display_name == DISPLAY_NAME:
                REASONING_ENGINE_NAME = a.api_resource.name
                break
        if REASONING_ENGINE_NAME is None:
            raise RuntimeError(f"Deployed agent '{DISPLAY_NAME}' not found.")
    return REASONING_ENGINE_NAME

def extract_text_and_auth(event):
    response_text = ""
    auth_request = None
    
    is_dict = isinstance(event, dict)
    
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
            function_calls = [call.model_dump(mode="json") if hasattr(call, "model_dump") else call for call in event.get_function_calls()]
        except Exception:
            pass
            
    for call in function_calls:
        call_name = call.get("name") if isinstance(call, dict) else getattr(call, "name", None)
        call_id = call.get("id") if isinstance(call, dict) else getattr(call, "id", None)
        call_args = call.get("args") if isinstance(call, dict) else getattr(call, "args", {})
        
        if call_name == "adk_request_credential":
            auth_config = call_args.get("authConfig", {})
            exchanged = auth_config.get("exchangedAuthCredential") or {}
            raw = auth_config.get("rawAuthCredential") or {}
            oauth2 = exchanged.get("oauth2") or raw.get("oauth2") or {}
            auth_uri = oauth2.get("authUri")
            nonce = oauth2.get("nonce")
            
            auth_request = {
                "pause": True,
                "call_id": call_id,
                "invocation_id": call_args.get("functionCallId"),
                "auth_uri": auth_uri,
                "nonce": nonce,
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
            function_calls = [call.model_dump(mode="json") if hasattr(call, "model_dump") else call for call in event.get_function_calls()]
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
            function_responses = [resp.model_dump(mode="json") if hasattr(resp, "model_dump") else resp for resp in event.get_function_responses()]
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

class SessionRequest(BaseModel):
    user_id: Optional[str] = "customer@cymbal-retail.com"

class ChatRequest(BaseModel):
    session_id: str
    message: str
    user_id: Optional[str] = "customer@cymbal-retail.com"

class ResumeRequest(BaseModel):
    session_id: str
    call_id: str
    invocation_id: str
    auth_uri: str
    user_id: Optional[str] = "customer@cymbal-retail.com"
    code: Optional[str] = None
    state: Optional[str] = None
    auth_response_uri: Optional[str] = None

@app.post("/api/session")
async def create_session(request: Optional[SessionRequest] = None):
    """Creates a new Reasoning Engine session on GEAP."""
    try:
        user_id = request.user_id if request else "customer@cymbal-retail.com"
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
        from fastapi.responses import JSONResponse
        response = JSONResponse(content={"session_id": session_id, "remote_session_name": api_response.response.name})
        response.set_cookie(key="session_id", value=session_id, path="/", samesite="lax")
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create session: {e}")

@app.post("/api/chat")
async def chat(request: ChatRequest):
    """Sends a chat message to the Reasoning Engine and checks for OAuth consent requirements."""
    try:
        engine_name = get_deployed_engine_name()
        remote_app = client.agent_engines.get(name=engine_name)
        
        # We execute the query via stream_query synchronously to fetch the response
        # and check if any event requests end-user credentials
        response_text = ""
        auth_request = None
        tool_calls = []
        
        for event in remote_app.stream_query(
            user_id=request.user_id or "customer@cymbal-retail.com",
            session_id=request.session_id,
            message=request.message
        ):
            print(f"[DEBUG CHAT EVENT] Raw Event: {event}")
            text, auth = extract_text_and_auth(event)
            response_text += text
            tool_calls.extend(extract_tool_calls(event))
            if auth:
                auth_request = auth
        
        if auth_request:
            global consent_sessions
            consent_sessions[request.session_id] = {
                "call_id": auth_request["call_id"],
                "invocation_id": auth_request["invocation_id"],
                "auth_uri": auth_request["auth_uri"],
                "nonce": auth_request["nonce"],
                "auth_config": auth_request["auth_config"],
                "user_id": request.user_id or "customer@cymbal-retail.com"
            }
            auth_request["tool_calls"] = tool_calls
            return auth_request
            
        return {"pause": False, "response": response_text, "tool_calls": tool_calls}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/resume")
async def resume(request: ResumeRequest):
    """Appends Keycloak OAuth callback credentials to session state and continues execution."""
    try:
        import asyncio
        await asyncio.sleep(2.0) # Allow FinalizeCredentials replication!
        engine_name = get_deployed_engine_name()
        
        # Load original authConfig from the in-memory consent_sessions cache
        global consent_sessions
        session_data = consent_sessions.get(request.session_id) or {}
        original_auth_config = session_data.get("auth_config") or {}
            
        import copy
        auth_response_config = copy.deepcopy(original_auth_config)
        
        exchanged = auth_response_config.get("exchangedAuthCredential") or {}
        raw = auth_response_config.get("rawAuthCredential") or {}
        oauth2 = exchanged.get("oauth2") or raw.get("oauth2") or {}
        oauth2["auth_response_uri"] = request.auth_response_uri
        oauth2["authResponseUri"] = request.auth_response_uri
        
        # Create the FunctionResponse Content matching the adk_request_credential call
        auth_content = types.Content(
            role="user",
            parts=[
                types.Part(
                    function_response=types.FunctionResponse(
                        name="adk_request_credential",
                        id=request.call_id,
                        response=auth_response_config
                    )
                )
            ]
        )
        
        user_id = request.user_id or "customer@cymbal-retail.com"
        
        # Invoke stream_query with the FunctionResponse content to resume execution cleanly
        remote_app = client.agent_engines.get(name=engine_name)
        response_text = ""
        auth_request = None
        tool_calls = []
        
        for event in remote_app.stream_query(
            user_id=user_id,
            session_id=request.session_id,
            message=auth_content.model_dump(mode="json")  # Pass the Content dict to resume!
        ):
            print(f"[DEBUG RESUME EVENT] Raw Event: {event}")
            text, auth = extract_text_and_auth(event)
            response_text += text
            tool_calls.extend(extract_tool_calls(event))
            if auth:
                auth_request = auth
                
        if auth_request:
            consent_sessions[request.session_id] = {
                "call_id": auth_request["call_id"],
                "invocation_id": auth_request["invocation_id"],
                "auth_uri": auth_request["auth_uri"],
                "nonce": auth_request["nonce"],
                "auth_config": auth_request["auth_config"]
            }
            auth_request["tool_calls"] = tool_calls
            return auth_request
            
        return {"pause": False, "response": response_text, "tool_calls": tool_calls}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/check_auth")
async def check_auth(session_id: str = Query(...)):
    """Checks if the Keycloak validation callback has completed for the given session_id."""
    global consent_sessions
    session_data = consent_sessions.get(session_id)
    if session_data and session_data.get("completed"):
        # Read the callback url and clear the completed flag so it is consumed once
        callback_url = session_data["callback_url"]
        session_data["completed"] = False
        return {"completed": True, "callback_url": callback_url}
    return {"completed": False}

# Serve index.html at the root
@app.get("/")
async def get_index():
    return FileResponse(os.path.join(os.path.dirname(__file__), "static", "index.html"))

# Serve the Keycloak OAuth callback landing page
@app.get("/callback")
async def oauth_callback(
    request: Request,
    code: Optional[str] = None,
    state: Optional[str] = None,
    user_id_validation_state: Optional[str] = None,
    connector_name: Optional[str] = None,
    auth_provider_name: Optional[str] = None
):
    """Keycloak OAuth callback validation page that finalizes credentials with Google Connectors API."""
    # Google Connector/Auth provider service passes auth_provider_name as the query parameter.
    resolved_connector_name = auth_provider_name or connector_name
    if not resolved_connector_name:
        raise HTTPException(status_code=400, detail="Missing connector_name or auth_provider_name parameter")
    global consent_sessions
    success = False
    err_detail = ""
    
    # Retrieve the session ID from browser cookies
    session_id = request.cookies.get("session_id")
    session_data = consent_sessions.get(session_id) if session_id else None
    
    if session_data:
        session_data["callback_url"] = str(request.url)
        consent_nonce = session_data.get("nonce")
        
        consent_user_id = session_data.get("user_id", "customer@cymbal-retail.com")
        import httpx
        payload = {
            "userId": consent_user_id,
            "userIdValidationState": user_id_validation_state,
            "consentNonce": consent_nonce
        }
        
        connector_path = resolved_connector_name.replace("/authProviders/", "/connectors/")
        finalize_url = f"https://iamconnectorcredentials.googleapis.com/v1alpha/{connector_path}/credentials:finalize"
        print(f"[DEBUG CALLBACK] Calling FinalizeCredentials on: {finalize_url}")
        print(f"[DEBUG CALLBACK] Payload: {payload}")
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as http_client:
                resp = await http_client.post(finalize_url, json=payload)
                print(f"[DEBUG CALLBACK] FinalizeCredentials Status: {resp.status_code}, Response: {resp.text}")
                resp.raise_for_status()
                print("[DEBUG CALLBACK] FinalizeCredentials completed successfully!")
                success = True
                # Mark the session as authenticated and completed
                session_data["completed"] = True
        except Exception as e:
            err_detail = e.response.text if hasattr(e, "response") else str(e)
            print(f"[DEBUG CALLBACK] Error calling FinalizeCredentials: {err_detail}")
    else:
        err_detail = f"No active pending session found for session_id '{session_id}'."
        print(f"[DEBUG CALLBACK] {err_detail}")

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Authentication Status</title>
        <style>
            body {{ font-family: 'Inter', sans-serif; background: #12131a; color: #e1e3eb; text-align: center; padding: 4rem; }}
            .card {{ background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); padding: 2rem; border-radius: 12px; display: inline-block; max-width: 500px; }}
            h3 {{ color: { "#4caf50" if success else "#f44336" }; }}
        </style>
    </head>
    <body>
        <div class="card">
            <h3>{"✓ Login Successful!" if success else "✗ Verification Failed"}</h3>
            <p>{"You can return to the chat window. This popup will close automatically." if success else f"Credentials finalization failed: {err_detail}"}</p>
        </div>
        <script>
            if ({ "true" if success else "false" }) {{
                setTimeout(() => {{
                    if (window.opener) {{
                        window.close();
                    }}
                }}, 1500);
            }}
        </script>
    </body>
    </html>
    """
    from fastapi.responses import HTMLResponse
    return HTMLResponse(content=html_content)

# Mount static folder for CSS/JS assets
app.mount("/static", StaticFiles(directory=os.path.join(os.path.dirname(__file__), "static")), name="static")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="127.0.0.1", port=9000, reload=True)
