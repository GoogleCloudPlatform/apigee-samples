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

# Now initialize Vertex AI and import ADK / agent details
from google.cloud import aiplatform
import vertexai
from vertexai import types
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

def ensure_iam_connector(project_id, location, engine_name, client_id, client_secret, apigee_hostname):
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

    connector_name = "idp-connector"
    
    # 2. Check if connector exists
    print(f"Checking if IAM connector '{connector_name}' exists...")
    res = subprocess.run(
        ["gcloud", "alpha", "agent-identity", "connectors", "describe", connector_name, f"--project={project_id}", f"--location={location}", "--format=json"],
        capture_output=True, text=True
    )
    
    connector_exists = False
    
    if res.returncode == 0:
        connector_exists = True
        try:
            connector_info = json.loads(res.stdout)
            if connector_info.get("deleted"):
                print("Connector exists but is soft-deleted. Undeleting it...")
                subprocess.run(
                    ["gcloud", "alpha", "agent-identity", "connectors", "undelete", connector_name, f"--project={project_id}", f"--location={location}"],
                    check=True
                )
                print("Connector undeleted successfully.")
        except Exception as e:
            print(f"Warning: Failed to parse connector info: {e}")

    if not connector_exists:
        if not client_id or not client_secret or not apigee_hostname:
            raise ValueError("Connector does not exist. --client-id, --client-secret, and --apigee-hostname must be provided to create it.")
        
        print(f"Connector '{connector_name}' does not exist. Creating it...")
        # Create the connector
        auth_url = f"https://{apigee_hostname}/authorize"
        token_url = f"https://{apigee_hostname}/token"
        
        subprocess.run([
            "gcloud", "alpha", "agent-identity", "connectors", "create", connector_name,
            f"--project={project_id}", f"--location={location}",
            f"--three-legged-oauth-client-id={client_id}",
            f"--three-legged-oauth-client-secret={client_secret}",
            f"--three-legged-oauth-authorization-url={auth_url}",
            f"--three-legged-oauth-token-url={token_url}",
            "--state=enabled"
        ], check=True)
        print(f"Connector '{connector_name}' created successfully.")
    else:
        # Update credentials on the existing connector to avoid stale configuration
        if client_id and client_secret and apigee_hostname:
            print(f"Connector '{connector_name}' already exists. Updating its credentials...")
            auth_url = f"https://{apigee_hostname}/authorize"
            token_url = f"https://{apigee_hostname}/token"
            subprocess.run([
                "gcloud", "alpha", "agent-identity", "connectors", "update", connector_name,
                f"--project={project_id}", f"--location={location}",
                f"--three-legged-oauth-client-id={client_id}",
                f"--three-legged-oauth-client-secret={client_secret}",
                f"--three-legged-oauth-authorization-url={auth_url}",
                f"--three-legged-oauth-token-url={token_url}"
            ], check=True)
            print(f"Connector '{connector_name}' updated successfully.")

    # 3. Add the IAM policy bindings
    print(f"Adding IAM policy binding for agent SPIFFE member: {member}...")
    subprocess.run([
        "gcloud", "alpha", "agent-identity", "connectors", "add-iam-policy-binding", connector_name,
        f"--project={project_id}", f"--location={location}",
        "--role=roles/iamconnectors.user",
        f"--member={member}"
    ], check=True)

    # Add the IAM policy binding for the developer's personal email
    try:
        email_res = subprocess.run(
            ["gcloud", "config", "get-value", "account"],
            capture_output=True, text=True, check=True
        )
        developer_email = email_res.stdout.strip()
        if developer_email:
            print(f"Adding IAM policy binding for developer: user:{developer_email}...")
            subprocess.run([
                "gcloud", "alpha", "agent-identity", "connectors", "add-iam-policy-binding", connector_name,
                f"--project={project_id}", f"--location={location}",
                "--role=roles/iamconnectors.user",
                f"--member=user:{developer_email}"
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

    print(f"Initializing Vertex AI SDK for project={project}, location={location}...")
    vertexai.init(project=project, location=location)
    client = vertexai.Client(project=project, location=location)

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
        "AGENT_REGISTRY_LOCATION": os.getenv("AGENT_REGISTRY_LOCATION", location),
        "OAUTH_CALLBACK_URL": os.getenv("OAUTH_CALLBACK_URL", "http://127.0.0.1:9000/callback"),
        "MODEL_NAME": os.getenv("MODEL_NAME", "gemini-2.5-flash"),
        "VERTEX_DEPLOYED": "true",
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
            "google-adk[agent-identity,a2a] == 1.36.1",
            "google-cloud-aiplatform[adk,agent-engines] >= 1.100.0, < 2.0.0",
            "python-dotenv >= 1.1.1, < 2.0.0",
            "fastapi >= 0.116.0",
            "google-cloud-secret-manager >= 2.24.0, < 3.0.0",
            "litellm"
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
    if args.egress_gateway:
        egress_path = args.egress_gateway
        if not egress_path.startswith("projects/"):
            egress_path = f"projects/{project}/locations/{location}/agentGateways/{args.egress_gateway}"
        gateway_config["agent_to_anywhere_config"] = {"agent_gateway": egress_path}

    if args.ingress_gateway:
        ingress_path = args.ingress_gateway
        if not ingress_path.startswith("projects/"):
            ingress_path = f"projects/{project}/locations/{location}/agentGateways/{args.ingress_gateway}"
        gateway_config["client_to_agent_config"] = {"agent_gateway": ingress_path}

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

    # # Ensure Agent Identity IAM connector is created and registered
    # print("\n🔒 Configuring Agent Identity IAM Connector...")
    # ensure_iam_connector(
    #     project,
    #     location,
    #     remote_agent.api_resource.name,
    #     client_id=args.client_id,
    #     client_secret=args.client_secret,
    #     apigee_hostname=args.apigee_hostname
    # )

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
