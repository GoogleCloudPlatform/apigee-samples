import argparse
import os
import sys
import json
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv

# Search up for the .env file and load it
def load_parent_env():
    current = Path(__file__).resolve().parent
    # Add agents directory to sys.path so we can import as a package
    sys.path.insert(0, str(current.parent))
    for parent in [current, *current.parents]:
        env_path = parent / ".env"
        if env_path.exists():
            load_dotenv(env_path)
            break

load_parent_env()

# Parse args early to set environment variables required by agent imports
def parse_args_and_set_env():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--project")
    parser.add_argument("--location", default="us-central1")
    args, _ = parser.parse_known_args()
    
    project = args.project or os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("PROJECT_ID")
    if project:
        os.environ["GOOGLE_CLOUD_PROJECT"] = project
        os.environ["PROJECT_ID"] = project
    
    location = args.location or os.getenv("GOOGLE_CLOUD_LOCATION") or os.getenv("VERTEXAI_REGION")
    if location:
        os.environ["GOOGLE_CLOUD_LOCATION"] = location
        os.environ["VERTEXAI_REGION"] = location

parse_args_and_set_env()

# Compatibility fix: allow google-auth's _MutualTlsAdapter to be safely serialized with cloudpickle
try:
    import google.auth.transport.requests as gar
    if hasattr(gar, "_MutualTlsAdapter"):
        def _mtls_setstate(self, state):
            self._ctx_poolmanager = state.get("_ctx_poolmanager")
            self._ctx_proxymanager = state.get("_ctx_proxymanager")
            super(gar._MutualTlsAdapter, self).__setstate__(state)
        gar._MutualTlsAdapter.__setstate__ = _mtls_setstate
except Exception:
    pass

# Now initialize Agent Platform and import ADK / agent details
from google.cloud import aiplatform
import agentplatform
from agentplatform import types
from vertexai.preview.reasoning_engines.templates.adk import AdkApp

try:
    from cymbal_retail_agent.agent import root_agent
except ImportError as e:
    # Only fallback if the root level import error is directly about cymbal_retail_agent.agent missing,
    # otherwise re-raise the nested error (e.g. missing dependencies)
    if e.name == 'cymbal_retail_agent' or e.name == 'cymbal_retail_agent.agent':
        from agent import root_agent
    else:
        raise

import cymbal_retail_agent
print(f"Loaded agent module from: {cymbal_retail_agent.__file__}")

import subprocess

def ensure_auth_provider(project_id, location, engine_name, client_id, client_secret, apigee_hostname):
    # engine_name format: projects/{project_number}/locations/{location}/reasoningEngines/{engine_id}
    parts = engine_name.split('/')
    project_number = parts[1]
    engine_id = parts[5]
    
    # 1. Determine if there is an organization ID
    org_id = None
    try:
        res = subprocess.run(
            ["gcloud", "projects", "get-ancestors", project_id, "--format=value(id,type)"],
            capture_output=True, text=True, check=True
        )
        for line in res.stdout.strip().split('\n'):
            if "organization" in line:
                org_id = line.split()[0]
                break
    except Exception as e:
        print(f"Warning: Failed to determine project ancestry: {e}")

    if org_id:
        member = f"principal://agents.global.org-{org_id}.system.id.goog/resources/aiplatform/projects/{project_number}/locations/{location}/reasoningEngines/{engine_id}"
    else:
        member = f"principal://agents.global.project-{project_number}.system.id.goog/resources/aiplatform/projects/{project_number}/locations/{location}/reasoningEngines/{engine_id}"

    auth_provider_name = os.getenv("AUTH_PROVIDER_NAME", "cymbal-idp")
    
    # 2. Check if auth provider exists
    print(f"Checking if Agent Identity auth provider '{auth_provider_name}' exists...")
    res = subprocess.run(
        ["gcloud", "beta", "agent-identity", "auth-providers", "describe", auth_provider_name, f"--project={project_id}", f"--location={location}", "--format=json"],
        capture_output=True, text=True
    )
    
    provider_exists = False
    
    if res.returncode == 0:
        provider_exists = True
        try:
            provider_info = json.loads(res.stdout)
            if provider_info.get("deleted"):
                print("Auth provider exists but is soft-deleted. Undeleting it...")
                subprocess.run(
                    ["gcloud", "beta", "agent-identity", "auth-providers", "undelete", auth_provider_name, f"--project={project_id}", f"--location={location}"],
                    check=True
                )
                print("Auth provider undeleted successfully.")
        except Exception as e:
            print(f"Warning: Failed to parse auth provider info: {e}")

    if not provider_exists:
        if not client_id or not client_secret or not apigee_hostname:
            raise ValueError("Auth provider does not exist. --client-id, --client-secret, and --apigee-hostname must be provided to create it.")
        
        print(f"Auth provider '{auth_provider_name}' does not exist. Creating it...")
        # Create the auth provider
        auth_url = f"https://{apigee_hostname}/authorize"
        token_url = f"https://{apigee_hostname}/token"
        
        subprocess.run([
            "gcloud", "beta", "agent-identity", "auth-providers", "create", auth_provider_name,
            f"--project={project_id}", f"--location={location}", f"--description=Cymbal Auth Provider (Apigee)",
            f"--three-legged-oauth-client-id={client_id}",
            f"--three-legged-oauth-client-secret={client_secret}",
            f"--three-legged-oauth-authorization-url={auth_url}",
            f"--three-legged-oauth-token-url={token_url}"
        ], check=True)
        print(f"Auth provider '{auth_provider_name}' created successfully.")
    else:
        # Update credentials on the existing auth provider to avoid stale configuration
        if client_id and client_secret and apigee_hostname:
            print(f"Auth provider '{auth_provider_name}' already exists. Updating its credentials...")
            auth_url = f"https://{apigee_hostname}/authorize"
            token_url = f"https://{apigee_hostname}/token"
            subprocess.run([
                "gcloud", "beta", "agent-identity", "auth-providers", "update", auth_provider_name,
                f"--project={project_id}", f"--location={location}", f"--description=Cymbal Auth Provider (Apigee)",
                f"--three-legged-oauth-client-id={client_id}",
                f"--three-legged-oauth-client-secret={client_secret}",
                f"--three-legged-oauth-authorization-url={auth_url}",
                f"--three-legged-oauth-token-url={token_url}"
            ], check=True)
            print(f"Auth provider '{auth_provider_name}' updated successfully.")

    # 3. Add the IAM policy bindings
    print(f"Adding IAM policy binding for agent SPIFFE member: {member}...")
    subprocess.run([
        "gcloud", "beta", "agent-identity", "auth-providers", "add-iam-policy-binding", auth_provider_name,
        f"--project={project_id}", f"--location={location}",
        "--role=roles/agentidentity.user",
        f"--member={member}"
    ], check=True)

    # Add the IAM policy binding for the developer's personal email or service account
    try:
        email_res = subprocess.run(
            ["gcloud", "config", "get-value", "account"],
            capture_output=True, text=True, check=True
        )
        developer_email = email_res.stdout.strip()
        if developer_email:
            member_type = "serviceAccount" if developer_email.endswith(".gserviceaccount.com") else "user"
            print(f"Adding IAM policy binding for developer: {member_type}:{developer_email}...")
            subprocess.run([
                "gcloud", "beta", "agent-identity", "auth-providers", "add-iam-policy-binding", auth_provider_name,
                f"--project={project_id}", f"--location={location}",
                "--role=roles/agentidentity.user",
                f"--member={member_type}:{developer_email}"
            ], check=True)
    except Exception as e:
        print(f"Warning: Failed to add developer IAM policy binding: {e}")

def deploy(args):
    # Normalize inputs
    project = args.project or os.getenv("GOOGLE_CLOUD_PROJECT")
    if not project:
        raise ValueError("Project ID must be specified (via --project or GOOGLE_CLOUD_PROJECT env var)")

    location = args.location or "us-central1"
    staging_bucket = args.bucket
    if not staging_bucket.startswith("gs://"):
        staging_bucket = f"gs://{staging_bucket}"

    print(f"Initializing Agent Platform SDK for project={project}, location={location}...")
    agentplatform.init(project=project, location=location)
    client = agentplatform.Client(project=project, location=location)

    # Check for existing reasoning engine with the same display name
    print(f"Checking for existing deployments with display_name='{args.display_name}'...")
    matching_agents = []
    try:
        for engine in client.agent_engines.list():
            if getattr(engine.api_resource, "display_name", None) == args.display_name:
                matching_agents.append(engine)
    except Exception as e:
        print(f"Warning: Failed to list existing engines: {e}")

    # Wrap the agent in AdkApp
    local_agent = AdkApp(
        agent=root_agent,
    )

    env_vars = {
        "PROJECT_ID": project,
        "APIGEE_HOSTNAME": args.apigee_hostname or os.getenv("APIGEE_HOSTNAME", ""),
        "AGENT_REGISTRY_LOCATION": os.getenv("AGENT_REGISTRY_LOCATION", location),
        "AUTH_PROVIDER_NAME": os.getenv("AUTH_PROVIDER_NAME", "cymbal-idp"),
        "OAUTH_CALLBACK_URL": os.getenv("OAUTH_CALLBACK_URL", "http://127.0.0.1:9000/callback"),
        "MODEL_NAME": os.getenv("MODEL_NAME", "gemini-2.5-flash"),
        # Enable Agent Telemetry and Observability settings for Google Cloud Console
        "GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY": "true",
        "OTEL_SEMCONV_STABILITY_OPT_IN": "gen_ai_latest_experimental",
        "OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT": "EVENT_ONLY",
    }

    agent_dir = Path(__file__).resolve().parent
    
    # Change working directory to the parent folder of the agent so that the
    # packaging system packages "cymbal_retail_agent" as a relative top-level directory.
    # This prevents absolute paths from being preserved in the uploaded tar archive.
    os.chdir(str(agent_dir.parent))

    # Load requirements directly from pyproject.toml
    pyproject_path = Path(__file__).resolve().parent.parent / "pyproject.toml"
    requirements = []
    if pyproject_path.exists():
        try:
            import tomllib
            with open(pyproject_path, "rb") as f:
                data = tomllib.load(f)
                requirements = data.get("project", {}).get("dependencies", [])
        except Exception:
            pass
            
    if not requirements:
        requirements = [
            "google-cloud-aiplatform[reasoningengine]",
            "cloudpickle",
            "pydantic",
            "google-adk[agent-identity,mcp]>=2.3.0,<3.0.0",
            "a2a-sdk>=0.3.4,<0.4.0",
            "pyopenssl<26",
            "python-dotenv",
            "fastapi",
            "google-cloud-secret-manager",
            "litellm",
        ]

    config = {
        "display_name": args.display_name,
        "description": args.description,
        "staging_bucket": staging_bucket,
        "extra_packages": ["cymbal_retail_agent"],
        "requirements": requirements,
        "env_vars": env_vars,
    }

    # Handle Gateways
    gateway_config = {}
    if args.egress_gateway and args.egress_gateway != "None":
        egress_gw_name = args.egress_gateway.split("/")[-1]
        gw_check = subprocess.run(
            ["gcloud", "network-services", "agent-gateways", "describe", egress_gw_name,
             f"--project={project}", f"--location={location}"],
            capture_output=True, text=True
        )
        if gw_check.returncode == 0:
            egress_path = args.egress_gateway
            if not egress_path.startswith("projects/"):
                egress_path = f"projects/{project}/locations/{location}/agentGateways/{args.egress_gateway}"
            gateway_config["agent_to_anywhere_config"] = {"agent_gateway": egress_path}
        else:
            print(f"INFO: Agent Gateway '{args.egress_gateway}' not found in project. Proceeding with standard Agent Platform identity.")

    if args.ingress_gateway and args.ingress_gateway != "None":
        ingress_gw_name = args.ingress_gateway.split("/")[-1]
        gw_check = subprocess.run(
            ["gcloud", "network-services", "agent-gateways", "describe", ingress_gw_name,
             f"--project={project}", f"--location={location}"],
            capture_output=True, text=True
        )
        if gw_check.returncode == 0:
            ingress_path = args.ingress_gateway
            if not ingress_path.startswith("projects/"):
                ingress_path = f"projects/{project}/locations/{location}/agentGateways/{args.ingress_gateway}"
            gateway_config["client_to_agent_config"] = {"agent_gateway": ingress_path}
        else:
            print(f"INFO: Ingress Gateway '{args.ingress_gateway}' not found in project.")

    if gateway_config:
        config["agent_gateway_config"] = gateway_config
        config["identity_type"] = types.IdentityType.AGENT_IDENTITY
        env_vars["GOOGLE_API_PREVENT_AGENT_TOKEN_SHARING_FOR_GCP_SERVICES"] = "False"
        print(f"Configuring Agent Gateway integration...")
        print(f"  Egress Gateway: {gateway_config.get('agent_to_anywhere_config', {}).get('agent_gateway', 'None')}")
        print(f"  Ingress Gateway: {gateway_config.get('client_to_agent_config', {}).get('agent_gateway', 'None')}")

    if matching_agents:
        existing_agent = matching_agents[0]
        resource_name = existing_agent.api_resource.name
        print(f"\n🔄 Updating existing Agent Runtime instance: {resource_name}...")
        remote_agent = client.agent_engines.update(
            name=resource_name,
            agent=local_agent,
            config=config,
        )
    else:
        print(f"\n🚀 Creating new Agent Runtime instance...")
        remote_agent = client.agent_engines.create(
            agent=local_agent,
            config=config,
        )

    print("\n✅ Deployment successful!")
    print(f"Agent Runtime ID: {remote_agent.api_resource.name}")

    # Ensure Agent Identity Auth Provider is created and registered
    print("\n🔒 Configuring Agent Identity Auth Provider...")
    ensure_auth_provider(
        project,
        location,
        remote_agent.api_resource.name,
        client_id=args.client_id,
        client_secret=args.client_secret,
        apigee_hostname=args.apigee_hostname
    )

    # Ensure Agent Registry Binding is created/updated
    print("\n🔗 Configuring Agent Registry Binding...")
    ensure_agent_registry_binding(
        project,
        location,
        remote_agent.api_resource.name
    )

def ensure_agent_registry_binding(project_id, location, engine_name, auth_provider_name=None, continue_uri=None):
    """Creates or updates the Agent Registry Binding between the deployed Reasoning Engine and MCP Server."""
    import time
    engine_id = engine_name.split("/")[-1]
    auth_provider = auth_provider_name or os.getenv("AUTH_PROVIDER_NAME", "cymbal-idp")
    continue_uri = continue_uri or os.getenv("OAUTH_CALLBACK_URL", "http://127.0.0.1:9000/callback")
    
    try:
        proj_res = subprocess.run(
            ["gcloud", "projects", "describe", project_id, "--format=value(projectNumber)"],
            capture_output=True, text=True, check=True
        )
        project_number = proj_res.stdout.strip()
    except Exception as e:
        print(f"Warning: Failed to get project number for binding: {e}")
        return

    source_identifier = f"urn:agent:projects-{project_number}:projects:{project_number}:locations:{location}:aiplatform:reasoningEngines:{engine_id}"

    target_identifier = None
    try:
        mcp_res = subprocess.run(
            ["gcloud", "agent-registry", "mcp-servers", "list", f"--project={project_id}", f"--location={location}", "--format=json"],
            capture_output=True, text=True
        )
        if mcp_res.returncode == 0:
            servers = json.loads(mcp_res.stdout)
            for s in servers:
                if s.get("displayName") == "cymbal-discovery-v1" or "cymbal" in s.get("displayName", ""):
                    target_identifier = s.get("mcpServerId")
                    break
    except Exception as e:
        print(f"Warning: Failed to list MCP servers: {e}")

    if not target_identifier:
        try:
            ep_res = subprocess.run(
                ["gcloud", "agent-registry", "endpoints", "list", f"--project={project_id}", f"--location={location}", "--format=json"],
                capture_output=True, text=True
            )
            if ep_res.returncode == 0:
                endpoints = json.loads(ep_res.stdout)
                for ep in endpoints:
                    if ep.get("displayName") == "Apigee Host" or "apigee" in ep.get("displayName", "").lower():
                        target_identifier = ep.get("endpointId")
                        break
        except Exception as e:
            print(f"Warning: Failed to list Endpoints: {e}")

    if not target_identifier:
        target_identifier = f"urn:endpoint:projects-{project_number}:projects:{project_number}:locations:{location}:agentregistry:services:apigee-host"

    binding_name = "cymbal-auth-binding"
    auth_provider_path = f"projects/{project_id}/locations/{location}/authProviders/{auth_provider}"

    max_retries = 18
    retry_delay = 10
    success = False

    for attempt in range(1, max_retries + 1):
        print(f"Configuring Agent Registry Binding '{binding_name}' (attempt {attempt}/{max_retries})...")
        describe_res = subprocess.run(
            ["gcloud", "agent-registry", "bindings", "describe", binding_name, f"--project={project_id}", f"--location={location}"],
            capture_output=True, text=True
        )

        action = "update" if describe_res.returncode == 0 else "create"
        cmd = [
            "gcloud", "agent-registry", "bindings", action, binding_name,
            f"--project={project_id}", f"--location={location}",
            f"--source-identifier={source_identifier}",
            f"--target-identifier={target_identifier}",
            f"--auth-provider-binding={auth_provider_path}",
            "--auth-provider-binding-scopes=customer",
            f"--auth-provider-binding-continue-uri={continue_uri}"
        ]

        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            print(f"✅ Agent Registry Binding '{binding_name}' configured successfully.")
            success = True
            break

        err_msg = res.stderr.strip()
        print(f"Warning: Failed to configure Agent Registry binding (attempt {attempt}/{max_retries}): {err_msg}")
        if attempt < max_retries:
            print(f"Waiting {retry_delay}s for Reasoning Engine / resources to be indexed in Agent Registry...")
            time.sleep(retry_delay)

    if not success:
        raise RuntimeError(f"Failed to configure Agent Registry binding '{binding_name}' after {max_retries} attempts.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Deploy agent to Agent Runtime")
    parser.add_argument("--project", help="Google Cloud Project ID (defaults to GOOGLE_CLOUD_PROJECT env var)")
    parser.add_argument("--location", default="us-central1", help="Google Cloud Region/Location (defaults to us-central1)")
    parser.add_argument("--bucket", required=True, help="Cloud Storage staging bucket (e.g. my-bucket-name or gs://my-bucket-name)")
    parser.add_argument("--egress-gateway", help="Name or full resource path of Egress Agent Gateway")
    parser.add_argument("--ingress-gateway", help="Name or full resource path of Ingress Agent Gateway")
    parser.add_argument("--display-name", default="cymbal-retail-agent", help="Display name for the agent engine")
    parser.add_argument("--description", default="Cymbal Retail Agent", help="Description of the agent")
    parser.add_argument("--client-id", default=os.getenv("CLIENT_ID") or os.getenv("APIGEE_CLIENT_ID"), help="OAuth client ID")
    parser.add_argument("--client-secret", default=os.getenv("CLIENT_SECRET") or os.getenv("APIGEE_CLIENT_SECRET"), help="OAuth client secret")
    parser.add_argument("--apigee-hostname", default=os.getenv("APIGEE_HOSTNAME"), help="Apigee gateway hostname")

    args = parser.parse_args()
    deploy(args)
