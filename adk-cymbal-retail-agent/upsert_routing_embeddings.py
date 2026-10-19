#!/usr/bin/env python3
"""
Copyright 2026 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

import subprocess
import json
import urllib.request
import urllib.error
import logging
import sys
import argparse
import os
import time

# Configure logging format and level
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Default Configurations
INDEX_ID = "5904894211622174720"
PROJECT_ID = "apigee-ai"
REGION = "us-central1"
EMBEDDING_URL = ""

# Training Dataset for Semantic Model Routing:
# - Simple & General queries are prefixed with "simple_"
# - Retail domain queries (Sections 3-9) are prefixed with "gemma_"
# - Complex queries are prefixed with "complex_"
DATASET = [
    # =========================================================================
    # Simple & General Queries (Routed to Gemini Flash / Fallback Model)
    # Prefixed with "simple_"
    # =========================================================================
    
    # 1. Greetings & Salutations
    {"text": "Hello", "id": "simple_greeting_1"},
    {"text": "Hi there", "id": "simple_greeting_2"},
    {"text": "Hey", "id": "simple_greeting_3"},
    {"text": "Good morning", "id": "simple_greeting_4"},
    {"text": "Good afternoon", "id": "simple_greeting_5"},
    {"text": "Good evening", "id": "simple_greeting_6"},

    # 2. General Assistance & Basic Tasks
    {"text": "How are you?", "id": "simple_assistance_1"},
    {"text": "What can you do?", "id": "simple_assistance_2"},
    {"text": "Help me please", "id": "simple_assistance_3"},
    {"text": "Can you help me?", "id": "simple_assistance_4"},
    {"text": "Translate hello to Spanish", "id": "simple_translation_1"},
    {"text": "How do you say thank you in French?", "id": "simple_translation_2"},
    {"text": "What is 2 + 2?", "id": "simple_math_1"},
    {"text": "Calculate 15% of 80", "id": "simple_math_2"},
    {"text": "Write a short sentence about dogs.", "id": "simple_writing_1"},
    {"text": "Tell me a joke", "id": "simple_joke_1"},

    # =========================================================================
    # Retail FAQ Queries (Routed to Local Gemma 3 Model)
    # Prefixed with "gemma_" (Sections 3 to 9)
    # =========================================================================

    # 3. Store Hours & Schedules
    {"text": "What are your store hours?", "id": "gemma_store_hours_1"},
    {"text": "What time do you open and close?", "id": "gemma_store_hours_2"},
    {"text": "When are you open?", "id": "gemma_store_hours_3"},
    {"text": "What are the operating hours?", "id": "gemma_store_hours_4"},

    # 4. Return, Refund & Exchange Policy
    {"text": "What is your return policy?", "id": "gemma_return_policy_1"},
    {"text": "How do I return an item?", "id": "gemma_return_policy_2"},
    {"text": "What is your refund policy?", "id": "gemma_return_policy_3"},
    {"text": "How does item exchange work?", "id": "gemma_return_policy_4"},

    # 5. Shipping Rates, Costs & Options
    {"text": "What are your shipping rates?", "id": "gemma_shipping_1"},
    {"text": "How much does shipping cost?", "id": "gemma_shipping_2"},
    {"text": "What shipping options and methods do you offer?", "id": "gemma_shipping_3"},
    {"text": "How long does shipping take?", "id": "gemma_shipping_4"},

    # 6. Loyalty Program & Rewards Points
    {"text": "How do loyalty points work?", "id": "gemma_loyalty_1"},
    {"text": "Tell me about your rewards program", "id": "gemma_loyalty_2"},
    {"text": "What are the loyalty program tiers?", "id": "gemma_loyalty_3"},

    # 7. Store Locations & Address
    {"text": "Where are your store locations?", "id": "gemma_store_location_1"},
    {"text": "What is your store address?", "id": "gemma_store_location_2"},
    {"text": "Where are you located?", "id": "gemma_store_location_3"},

    # 8. Customer Support Contact
    {"text": "How can I contact customer service?", "id": "gemma_customer_support_1"},
    {"text": "What is your support email?", "id": "gemma_customer_support_2"},
    {"text": "What is your support phone number?", "id": "gemma_customer_support_3"},

    # 9. Order Cancellation Policy
    {"text": "What is your order cancellation policy?", "id": "gemma_cancellation_policy_1"},
    {"text": "How do I cancel my order?", "id": "gemma_cancellation_policy_2"},

    # =========================================================================
    # Complex Queries (Routed to Managed Frontier Gemini Pro)
    # Prefixed with "complex_"
    # =========================================================================
    {"text": "Write a highly resilient Python function using exponential backoff that fetches a URL and parses JSON.", "id": "complex_code_1"},
    {"text": "Explain the difference between deep learning and classical machine learning in detail.", "id": "complex_explanation_1"},
    {"text": "Given a list of integers, find the longest contiguous subsegment with sum equal to k.", "id": "complex_algorithms_1"},
    {"text": "Analyze the performance bottlenecks of this React application component.", "id": "complex_analysis_1"},
    {"text": "Design a system architecture for a real-time chat application handling 10 million daily active users.", "id": "complex_system_design_1"},
    {"text": "Write a bash script to parse logs, extract error rates, and send an email alert if errors exceed 5%.", "id": "complex_script_1"},
    {"text": "Explain quantum computing to a 5 year old vs a college student.", "id": "complex_explanation_2"},
    {"text": "Refactor this SQL query to use window functions and optimize performance on large datasets.", "id": "complex_db_1"}
]

def get_token():
    """
    Fetches the OAuth 2.0 access token using gcloud CLI.
    """
    try:
        res = subprocess.run(["gcloud", "auth", "print-access-token"], capture_output=True, text=True, check=True)
        return res.stdout.strip()
    except Exception as e:
        logging.error(f"Failed to get access token: {e}")
        return None

def get_embeddings_batch(texts, token, batch_size=100, max_retries=3):
    """
    Generates text embedding vectors in batches using Vertex AI text-embedding-005 model.
    Batching up to 100 prompts per request avoids per-minute request quota exhaustion (HTTP 429).
    """
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }
    results = []
    for start in range(0, len(texts), batch_size):
        chunk = texts[start:start + batch_size]
        payload = {
            "instances": [{"content": text} for text in chunk]
        }
        data = json.dumps(payload).encode("utf-8")
        chunk_vectors = None

        for attempt in range(max_retries):
            req = urllib.request.Request(EMBEDDING_URL, data=data, headers=headers, method="POST")
            try:
                with urllib.request.urlopen(req, timeout=60.0) as response:
                    if response.status == 200:
                        body = json.loads(response.read().decode("utf-8"))
                        predictions = body.get("predictions", [])
                        if len(predictions) == len(chunk):
                            chunk_vectors = [p.get("embeddings", {}).get("values") for p in predictions]
                            break
                logging.warning(f"Unexpected response size generating batch embeddings (batch offset {start}).")
                break
            except urllib.error.HTTPError as e:
                error_body = e.read().decode("utf-8", errors="replace")
                if e.code in (429, 500, 502, 503, 504) and attempt < max_retries - 1:
                    delay = 5 * (2 ** attempt)
                    logging.warning(
                        f"Transient HTTP {e.code} calling batch embedding API (attempt {attempt + 1}/{max_retries}); retrying in {delay}s..."
                    )
                    time.sleep(delay)
                    continue
                logging.warning(
                    f"Batch embedding API returned HTTP {e.code} after {attempt + 1} attempt(s); falling back to precomputed vectors where available. Details: {error_body}"
                )
                break
            except Exception as e:
                logging.warning(f"Error calling batch embedding API: {e}")
                break

        if chunk_vectors:
            results.extend(chunk_vectors)
        else:
            results.extend([None] * len(chunk))

    return results

def load_precomputed_map():
    """
    Loads precomputed 768-dim text-embedding-005 vectors indexed by datapointId.
    """
    precomputed_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "precomputed_routing_datapoints.json")
    if not os.path.exists(precomputed_file):
        return {}
    try:
        with open(precomputed_file, "r") as f:
            entries = json.load(f)
        return {entry["datapointId"]: entry["featureVector"] for entry in entries if "datapointId" in entry and "featureVector" in entry}
    except Exception as e:
        logging.warning(f"Unable to read precomputed embeddings file {precomputed_file}: {e}")
        return {}

def main():
    global INDEX_ID, PROJECT_ID, REGION, EMBEDDING_URL

    parser = argparse.ArgumentParser(description="Upload prompt embeddings to Vertex AI Index for Semantic Routing")
    parser.add_argument("-p", "--project", help="GCP Project ID")
    parser.add_argument("-r", "--region", help="Vertex AI Region")
    parser.add_argument("-i", "--index-id", help="Vertex AI Index ID")
    args = parser.parse_args()

    project_id = args.project
    region = args.region
    index_id = args.index_id

    # Fallback to interactive prompts if executed in a TTY terminal
    if sys.stdin.isatty():
        if not project_id:
            project_id = input(f"Enter GCP Project ID [{PROJECT_ID}]: ").strip()
        if not region:
            region = input(f"Enter Vertex AI Region [{REGION}]: ").strip()
        if not index_id:
            index_id = input(f"Enter Vertex AI Index ID [{INDEX_ID}]: ").strip()

    # Apply resolved configuration values
    PROJECT_ID = project_id or PROJECT_ID
    REGION = region or REGION
    INDEX_ID = index_id or INDEX_ID

    EMBEDDING_URL = f"https://{REGION}-aiplatform.googleapis.com/v1/projects/{PROJECT_ID}/locations/{REGION}/publishers/google/models/text-embedding-005:predict"

    token = get_token()
    if not token:
        sys.exit(1)

    datapoints = []
    precomputed_map = load_precomputed_map()
    logging.info(f"Using Project: {PROJECT_ID}, Region: {REGION}, Index: {INDEX_ID}")
    logging.info(f"Generating embeddings for {len(DATASET)} routing prompts in a single batched request...")

    vectors = get_embeddings_batch([item["text"] for item in DATASET], token)
    live_count = 0
    fallback_count = 0

    for item, vector in zip(DATASET, vectors):
        item_id = item["id"]
        if vector:
            datapoints.append({
                "datapointId": item_id,
                "featureVector": vector
            })
            live_count += 1
        elif item_id in precomputed_map:
            datapoints.append({
                "datapointId": item_id,
                "featureVector": precomputed_map[item_id]
            })
            fallback_count += 1
        else:
            logging.error(f"Missing both live and precomputed embedding vector for datapoint '{item_id}'.")

    logging.info(
        f"Prepared {len(datapoints)}/{len(DATASET)} routing embeddings (live batched: {live_count}, precomputed fallback: {fallback_count})."
    )

    if not datapoints:
        logging.error("No datapoints generated and no precomputed fallback file found. Exiting.")
        sys.exit(1)

    # Save generated datapoints to temporary JSON file
    temp_filepath = os.path.abspath("routing_datapoints.json")
    with open(temp_filepath, "w") as f:
        json.dump(datapoints, f, indent=2)

    logging.info(f"Saved {len(datapoints)} datapoints to {temp_filepath}")

    # Upsert datapoints to Vertex AI Vector Search index
    cmd = [
        "gcloud", "ai", "indexes", "upsert-datapoints", INDEX_ID,
        f"--datapoints-from-file={temp_filepath}",
        f"--project={PROJECT_ID}",
        f"--region={REGION}"
    ]

    logging.info("Upserting datapoints to Vertex AI index...")
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        logging.info(f"Successfully upserted datapoints: {res.stdout.strip()}")
        os.remove(temp_filepath)
        logging.info("Cleaned up temporary datapoints file.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to upsert datapoints. Stderr: {e.stderr}")
        if os.path.exists(temp_filepath):
            os.remove(temp_filepath)
        sys.exit(1)

if __name__ == "__main__":
    main()
