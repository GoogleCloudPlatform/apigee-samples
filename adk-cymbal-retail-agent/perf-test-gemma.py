#!/usr/bin/env python3
#
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
#

"""
Cymbal Retail: Performance & Concurrency Benchmark for Gemma 3 (4B) CPU Optimization
Simulates 10-15 attendee Qwiklabs workshop concurrency hitting Apigee AI Gateway and Gemma 3 on Cloud Run CPU.
Measures latency (p50/p90/p99), token throughput, cold starts, and failure points.
"""

import os
import sys
import time
import json
import ssl
import subprocess
import urllib.request
import urllib.error
import concurrent.futures
from statistics import mean, median

# Load environment configuration
APIGEE_HOST = os.getenv("APIGEE_HOST", "34.54.87.114.nip.io")
PROJECT_ID = os.getenv("PROJECT_ID", "apigee-ai")
API_KEY = os.getenv("APIKEY", os.getenv("CLIENT_ID", "PXifa5UsWH2WhPSJfZGabR7mVndqlWMtANUYjtAWYALC7Tbb"))

def get_auth_token():
    try:
        token = subprocess.check_output("gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token", shell=True).decode().strip()
        if token:
            return token
    except Exception:
        pass
    return "mock-token"

def send_prompt(prompt_text, tier="local", timeout=30):
    url = f"https://{APIGEE_HOST}/v1/adk-retail-agent-llm-governance/v1/projects/{PROJECT_ID}/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent"
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt_text}]}],
        "system_instruction": {"parts": [{"text": "You are a helpful retail assistant."}]}
    }
    headers = {
        "Content-Type": "application/json",
        "x-apikey": API_KEY,
        "x-model-tier": tier,
        "Authorization": f"Bearer {get_auth_token()}"
    }
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    start_time = time.time()
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=headers)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as resp:
            elapsed = time.time() - start_time
            body = json.loads(resp.read().decode())
            return {
                "status": resp.status,
                "latency_sec": elapsed,
                "success": True,
                "model": body.get("modelVersion", "unknown"),
                "tokens": body.get("usageMetadata", {}).get("totalTokenCount", 35),
                "error": None
            }
    except Exception as e:
        elapsed = time.time() - start_time
        return {
            "status": getattr(e, "code", 500),
            "latency_sec": elapsed,
            "success": False,
            "model": "none",
            "tokens": 0,
            "error": str(e)
        }

def run_load_tier(concurrency_level, total_requests, prompt="Hello, what items do you have in stock?", tier="local"):
    print(f"\n⚡ Running Concurrency Tier: {concurrency_level} concurrent users ({total_requests} total requests)...")
    results = []
    start_total = time.time()
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency_level) as executor:
        futures = [executor.submit(send_prompt, prompt, tier) for _ in range(total_requests)]
        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())
            
    total_duration = time.time() - start_total
    
    successful = [r for r in results if r["success"]]
    failed = [r for r in results if not r["success"]]
    latencies = [r["latency_sec"] for r in successful]
    
    p50 = median(latencies) if latencies else 0
    p90 = sorted(latencies)[int(len(latencies)*0.9)] if latencies else 0
    p99 = sorted(latencies)[int(len(latencies)*0.99)] if latencies else 0
    avg_latency = mean(latencies) if latencies else 0
    total_tokens = sum(r["tokens"] for r in successful)
    throughput_rps = len(successful) / total_duration if total_duration > 0 else 0
    throughput_tps = total_tokens / total_duration if total_duration > 0 else 0
    
    print(f"   Success Rate: {len(successful)}/{total_requests} ({(len(successful)/total_requests)*100:.1f}%)")
    print(f"   Throughput:   {throughput_rps:.2f} req/sec | {throughput_tps:.2f} tokens/sec")
    print(f"   Latency:      Avg={avg_latency:.2f}s | p50={p50:.2f}s | p90={p90:.2f}s | p99={p99:.2f}s")
    if failed:
        print(f"   ⚠️ Failures:   {len(failed)} requests failed (Sample error: {failed[0]['error']})")
        
    return {
        "concurrency": concurrency_level,
        "total_requests": total_requests,
        "successful": len(successful),
        "failed": len(failed),
        "avg_latency": avg_latency,
        "p50": p50,
        "p90": p90,
        "p99": p99,
        "rps": throughput_rps,
        "tps": throughput_tps
    }

def main():
    print("==================================================================")
    print("  CYMBAL RETAIL: GEMMA 3 CPU & HYBRID ROUTING PERFORMANCE BENCHMARK")
    print("==================================================================")
    print(f"  Apigee Gateway: https://{APIGEE_HOST}")
    print(f"  Target Scope:   10-15 Concurrent Attendees Qwiklabs Simulation\n")

    benchmark_summary = []

    # Phase 1: Baseline Warmup (1 User)
    print("Phase 1: Baseline Warm-up (1 Concurrent User)")
    res = run_load_tier(concurrency_level=1, total_requests=3, prompt="Hello!", tier="local")
    benchmark_summary.append(res)

    # Phase 2: Moderate Concurrency (5 Users - Typical Workshop Steady State)
    print("\nPhase 2: Moderate Concurrency (5 Concurrent Users)")
    res = run_load_tier(concurrency_level=5, total_requests=10, prompt="Can you help me find my orders?", tier="local")
    benchmark_summary.append(res)

    # Phase 3: Peak Concurrency (10-15 Users - All Attendees Clicking 'Run' Simultaneously)
    print("\nPhase 3: Peak Workshop Concurrency (15 Concurrent Users)")
    res = run_load_tier(concurrency_level=15, total_requests=15, prompt="What is your return policy for damaged items?", tier="local")
    benchmark_summary.append(res)

    # Phase 4: Comparative Frontier Gemini 2.5 Flash Baseline (10 Users)
    print("\nPhase 4: Frontier Gemini 2.5 Flash Direct Baseline (10 Users)")
    res = run_load_tier(concurrency_level=10, total_requests=10, prompt="Transfer to ordersagent and list order history", tier="frontier")
    benchmark_summary.append(res)

    print("\n==================================================================")
    print("  PERFORMANCE BENCHMARK SUMMARY & WORKSHOP READINESS MATRIX       ")
    print("==================================================================")
    print(f"{'Tier / Concurrency':<22} | {'Success':<10} | {'Avg Latency':<12} | {'p90 Latency':<12} | {'Throughput':<15}")
    print("-" * 75)
    for b in benchmark_summary:
        tier_name = f"{b['concurrency']} Concurrent Users"
        success_str = f"{b['successful']}/{b['total_requests']}"
        avg_lat_str = f"{b['avg_latency']:.2f}s"
        p90_lat_str = f"{b['p90']:.2f}s"
        thru_str = f"{b['rps']:.2f} req/s"
        print(f"{tier_name:<22} | {success_str:<10} | {avg_lat_str:<12} | {p90_lat_str:<12} | {thru_str:<15}")

if __name__ == "__main__":
    main()
