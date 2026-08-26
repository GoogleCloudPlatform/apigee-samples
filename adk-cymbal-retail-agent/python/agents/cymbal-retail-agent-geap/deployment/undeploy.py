import argparse
import os
import subprocess
import agentplatform
from google.cloud import aiplatform

def clean_auth_provider(project_id, location):
    auth_provider_name = os.getenv("AUTH_PROVIDER_NAME", "cymbal-idp")
    print(f"Checking if Agent Identity auth provider '{auth_provider_name}' exists...")
    res = subprocess.run(
        ["gcloud", "agent-identity", "auth-providers", "describe", auth_provider_name, f"--project={project_id}", f"--location={location}"],
        capture_output=True
    )
    if res.returncode == 0:
        print(f"Deleting Agent Identity auth provider '{auth_provider_name}'...")
        subprocess.run(
            ["gcloud", "agent-identity", "auth-providers", "delete", auth_provider_name, f"--project={project_id}", f"--location={location}", "--quiet"],
            check=True
        )
        print("Agent Identity auth provider deleted successfully.")
    else:
        print("Agent Identity auth provider does not exist. Skipping.")

def undeploy(args):
    project = args.project or os.getenv("GOOGLE_CLOUD_PROJECT")
    if not project:
        raise ValueError("Project ID must be specified (via --project or GOOGLE_CLOUD_PROJECT env var)")

    location = args.location or "us-central1"

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

    if matching_agents:
        for agent in matching_agents:
            resource_name = agent.api_resource.name
            print(f"Deleting Agent Runtime instance: {resource_name} (force=True)...")
            client.agent_engines.delete(name=resource_name, force=True)
            print("Deleted successfully.")
    else:
        print("No matching Agent Runtime instance found.")

    # Clean up the auth provider
    print("\n🔒 Cleaning up Agent Identity Auth Provider...")
    clean_auth_provider(project, location)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Undeploy agent from Agent Runtime")
    parser.add_argument("--project", help="Google Cloud Project ID (defaults to GOOGLE_CLOUD_PROJECT env var)")
    parser.add_argument("--location", default="us-central1", help="Google Cloud Region/Location (defaults to us-central1)")
    parser.add_argument("--display-name", default="cymbal-retail-agent", help="Display name of the agent to undeploy")

    args = parser.parse_args()
    undeploy(args)
