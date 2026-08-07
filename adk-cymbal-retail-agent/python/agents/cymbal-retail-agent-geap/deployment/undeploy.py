import argparse
import os
import subprocess
import vertexai
from google.cloud import aiplatform

def clean_iam_connector(project_id, location):
    connector_name = "idp-connector"
    print(f"Checking if IAM connector '{connector_name}' exists...")
    res = subprocess.run(
        ["gcloud", "alpha", "agent-identity", "connectors", "describe", connector_name, f"--project={project_id}", f"--location={location}"],
        capture_output=True
    )
    if res.returncode == 0:
        print(f"Deleting IAM connector '{connector_name}'...")
        subprocess.run(
            ["gcloud", "alpha", "agent-identity", "connectors", "delete", connector_name, f"--project={project_id}", f"--location={location}", "--quiet"],
            check=True
        )
        print("IAM connector deleted successfully.")
    else:
        print("IAM connector does not exist. Skipping.")

def undeploy(args):
    project = args.project or os.getenv("GOOGLE_CLOUD_PROJECT")
    if not project:
        raise ValueError("Project ID must be specified (via --project or GOOGLE_CLOUD_PROJECT env var)")

    location = args.location or "us-central1"

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

    if matching_agents:
        for agent in matching_agents:
            resource_name = agent.api_resource.name
            print(f"Deleting Agent Runtime instance: {resource_name}...")
            client.agent_engines.delete(name=resource_name)
            print("Deleted successfully.")
    else:
        print("No matching Agent Runtime instance found.")

    # Clean up the IAM connector
    print("\n🔒 Cleaning up Agent Identity IAM Connector...")
    clean_iam_connector(project, location)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Undeploy agent from Agent Runtime")
    parser.add_argument("--project", help="Google Cloud Project ID (defaults to GOOGLE_CLOUD_PROJECT env var)")
    parser.add_argument("--location", default="us-central1", help="Google Cloud Region/Location (defaults to us-central1)")
    parser.add_argument("--display-name", default="cymbal-retail-agent", help="Display name of the agent to undeploy")

    args = parser.parse_args()
    undeploy(args)
