#!/usr/bin/env python3
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

"""Automated Playwright/CDP Qwiklabs Provisioner + Headless gcloud Auth + E2E Runner.

Can either:
1. Connect to an authenticated Qwiklabs Chrome session (CDP port 9222), navigate
   to https://gcpstaging.qwiklabs.com/labs/663130 (auto-converting /edit URLs),
   click "Start Lab", wait for Terraform provisioning to complete, and scrape
   Username, Password, Project ID, Region, Apigee Hostname, and SSO URL directly
   from the Qwiklabs screen (<ql-lab-control-panel> shadow DOM), OR
2. Accept pre-provisioned --sso-url and --student-password flags directly.

Then automatically:
- Bootstraps headless student Chrome (port 19225) and completes unattended
  `gcloud auth login --no-launch-browser --update-adc` for the student user.
- Runs `run_workshop_e2e.py` through all 7 tasks and local assessment checks.
- Clicks all 7 "Check my progress" buttons on the Qwiklabs tab (if connected)
  and optionally clicks "End Lab".
"""

import argparse
import asyncio
import json
import os
import pty
import re
import select
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from playwright.async_api import async_playwright


def normalize_lab_url(url: str) -> str:
  """Converts .../labs/663130/edit to the Play view .../labs/663130."""
  u = url.strip()
  u = re.sub(r"/edit/?$", "", u)
  return u


async def extract_qwiklabs_panel_state(page) -> dict:
  """Pierces Qwiklabs Lit/Shadow DOM to read provisioning state and credentials."""
  return await page.evaluate("""() => {
    const collectFields = () => {
      const map = {};
      const record = (label, value) => {
        const k = String(label || '').trim();
        const v = String(value || '').trim();
        if (k && v) map[k] = v;
      };

      // 1. Read directly from Lit component properties (.labDetails) if present
      const panels = [
        document.querySelector('ql-lab-control-panel'),
        document.querySelector('ql-lab-control-side-sheet'),
      ].filter(Boolean);

      let ssoUrl = '';
      let isProvisioning = false;
      for (const p of panels) {
        if (p.provisioning) isProvisioning = true;
        if (Array.isArray(p.labDetails)) {
          for (const item of p.labDetails) {
            if (!item) continue;
            if (item.label && item.value) record(item.label, item.value);
            if (item.href && String(item.text || '').toLowerCase().includes('console')) {
              ssoUrl = item.href;
            }
          }
        }
      }

      // 2. Recursively walk all shadow roots for ql-credential-field, ql-copyable-input, and console buttons
      const visit = (root) => {
        if (!root) return;
        const els = root.querySelectorAll ? Array.from(root.querySelectorAll('*')) : [];
        for (const el of els) {
          const tag = (el.tagName || '').toLowerCase();
          if (tag === 'ql-credential-field' || tag === 'ql-copyable-input' || el.getAttribute?.('data-qa') === 'credential-field') {
            const label = el.getAttribute?.('label') || el.label || '';
            let val = el.getAttribute?.('value') || el.value || '';
            if (!val && el.shadowRoot) {
              const inp = el.shadowRoot.querySelector('input');
              if (inp && inp.value) val = inp.value;
            }
            record(label, val);
          }
          if (tag === 'ql-lab-connection-details' && Array.isArray(el.connectionDetails)) {
            for (const cd of el.connectionDetails) {
              if (cd && cd.label && cd.value) record(cd.label, cd.value);
            }
          }
          if ((tag === 'a' || tag === 'ql-button') && !ssoUrl) {
            const href = el.getAttribute?.('href') || el.href || '';
            const txt = (el.textContent || el.getAttribute?.('alt') || el.getAttribute?.('aria-label') || '').toLowerCase();
            if (href && (href.includes('google_sso') || href.includes('console.cloud.google.com') || txt.includes('google cloud console'))) {
              ssoUrl = href;
            }
          }
          if (el.shadowRoot) visit(el.shadowRoot);
        }
      };
      visit(document);

      const panel = document.querySelector('ql-lab-control-panel');
      const shadow = panel ? panel.shadowRoot : null;
      const shadowText = shadow ? (shadow.textContent || '') : (document.body ? document.body.innerText : '');
      if (
        (shadow && shadow.querySelector('.provisioning-banner, .loader, ql-activity-indicator, ql-spinner')) ||
        shadowText.includes('Provisioning lab resources') ||
        shadowText.includes('Estimated time remaining')
      ) {
        isProvisioning = true;
      }

      const ctrlBtn = shadow ? shadow.querySelector('ql-lab-control-button, #lab-control-button') : null;
      const btnText = ctrlBtn
        ? (ctrlBtn.shadowRoot ? (ctrlBtn.shadowRoot.textContent || '') : (ctrlBtn.textContent || '')).trim()
        : '';

      const timerEl = shadow ? shadow.querySelector('ql-lab-timer, #lab-timer') : null;
      const timerText = timerEl
        ? (timerEl.shadowRoot ? (timerEl.shadowRoot.textContent || '') : (timerEl.textContent || '')).trim()
        : '';

      const alertEl = document.querySelector('.alert, .flash, [role="alert"], ql-toast, ql-snackbar');
      const alertText = alertEl ? (alertEl.textContent || '').trim() : '';

      const isRunning = Boolean(
        window.ql?.labRun?.isRunning ||
        btnText.toLowerCase().includes('end') ||
        Object.keys(map).length > 0
      );

      return {
        url: location.href,
        title: document.title,
        isProvisioning,
        isRunning,
        buttonText: btnText,
        timerText,
        alertText,
        ssoUrl,
        fields: map,
      };
    };
    return collectFields();
  }""")


def map_extracted_fields(state: dict) -> dict:
  """Normalizes Qwiklabs field labels into standard keys."""
  fields = state.get("fields") or {}
  sso_url = state.get("ssoUrl") or ""
  out = {
      "username": "",
      "password": "",
      "project_id": "",
      "region": "",
      "apigee_host": "",
      "sso_url": sso_url,
  }
  for k, v in fields.items():
    kl = k.lower()
    if "user" in kl or "email" in kl:
      out["username"] = v
    elif "pass" in kl:
      out["password"] = v
    elif "project" in kl:
      out["project_id"] = v
    elif "region" in kl or "location" in kl:
      out["region"] = v
    elif "apigee" in kl and "host" in kl:
      out["apigee_host"] = v
    elif not out["apigee_host"] and v.endswith(".apiservices.dev"):
      out["apigee_host"] = v
  return out


async def provision_lab_via_playwright(
    qwiklabs_cdp_url: str,
    lab_url: str,
    timeout_sec: int = 1800,
) -> dict:
  """Starts the lab on Qwiklabs via Playwright CDP and scrapes credentials off the screen."""
  play_url = normalize_lab_url(lab_url)
  print(f"[Qwiklabs] Connecting to Chrome CDP at {qwiklabs_cdp_url} ...", flush=True)
  async with async_playwright() as p:
    browser = await p.chromium.connect_over_cdp(qwiklabs_cdp_url)
    context = browser.contexts[0] if browser.contexts else await browser.new_context()

    # Reuse existing tab for this lab if open, otherwise open a new tab
    page = None
    for existing in context.pages:
      if play_url in existing.url:
        page = existing
        break
    if page is None:
      page = await context.new_page()
      print(f"[Qwiklabs] Navigating to {play_url} ...", flush=True)
      await page.goto(play_url, wait_until="domcontentloaded", timeout=60000)
      await page.wait_for_timeout(4000)

    if "accounts.google.com" in page.url or "users/sign_in" in page.url:
      raise RuntimeError(
          f"Qwiklabs browser on {qwiklabs_cdp_url} is not signed in (currently at {page.url}). "
          "Run `./run_in_background.sh --init-qwiklabs-browser` and sign in once."
      )

    # Check if lab is already running; if not, click Start Lab
    st = await extract_qwiklabs_panel_state(page)
    if not st.get("isRunning") and not st.get("isProvisioning"):
      print("[Qwiklabs] Clicking 'Start Lab' ...", flush=True)
      start_res = await page.evaluate("""async () => {
        if (window.ql && window.ql.labRun && typeof window.ql.labRun.startLab === 'function') {
          window.ql.labRun.startLab({ accessSuccess: true, ackedQuotaWarning: true });
          return 'ql.labRun.startLab';
        }
        const panel = document.querySelector('ql-lab-control-panel');
        const btn = panel?.shadowRoot?.querySelector('ql-lab-control-button, #lab-control-button');
        if (btn) {
          const inner = btn.shadowRoot ? btn.shadowRoot.querySelector('ql-button, button, [role="button"]') : btn;
          (inner || btn).click();
          await new Promise(r => setTimeout(r, 1200));
          const dialog = document.querySelector('ql-dialog, [role="dialog"]');
          if (dialog) {
            const confirmBtn = dialog.shadowRoot
              ? dialog.shadowRoot.querySelector('ql-button[aria-label*="Start"], ql-button[aria-label*="Launch"], [data-qa="confirm-start-lab-button"]')
              : dialog.querySelector('button, ql-button');
            if (confirmBtn) confirmBtn.click();
          }
          return 'dom_click';
        }
        return 'button_not_found';
      }""")
      print(f"[Qwiklabs] Start Lab trigger result: {start_res}", flush=True)
    else:
      print(
          f"[Qwiklabs] Lab already active (running={st.get('isRunning')}, provisioning={st.get('isProvisioning')}).",
          flush=True,
      )

    # Poll until provisioning finishes and all student_visible_outputs are populated
    t0 = time.time()
    while time.time() - t0 < timeout_sec:
      await page.wait_for_timeout(5000)
      st = await extract_qwiklabs_panel_state(page)
      mapped = map_extracted_fields(st)
      elapsed = int(time.time() - t0)
      has_all_core = bool(
          mapped["username"]
          and mapped["password"]
          and mapped["project_id"]
          and mapped["region"]
      )
      print(
          f"[Qwiklabs +{elapsed}s] provisioning={st.get('isProvisioning')} "
          f"timer={st.get('timerText')!r} project={mapped['project_id']!r} "
          f"region={mapped['region']!r} user={mapped['username']!r} "
          f"pass={'***' if mapped['password'] else ''} "
          f"apigee_host={mapped['apigee_host']!r}",
          flush=True,
      )
      if not st.get("isProvisioning") and has_all_core:
        if not mapped["apigee_host"]:
          mapped["apigee_host"] = f"api-{mapped['project_id']}.apiservices.dev"
        print("[Qwiklabs] Provisioning and startup script complete!", flush=True)
        return mapped

    raise TimeoutError(f"Timed out after {timeout_sec}s waiting for Qwiklabs lab provisioning.")


async def check_qwiklabs_progress_and_optionally_end(
    qwiklabs_cdp_url: str,
    lab_url: str,
    end_lab: bool = False,
) -> dict:
  """Clicks all 'Check my progress' buttons on the Qwiklabs tab and optionally ends the lab."""
  play_url = normalize_lab_url(lab_url)
  async with async_playwright() as p:
    browser = await p.chromium.connect_over_cdp(qwiklabs_cdp_url)
    context = browser.contexts[0]
    page = next((pg for pg in context.pages if play_url in pg.url), None)
    if page is None:
      print("[Qwiklabs] Lab tab not found for progress check.", flush=True)
      return {}

    print("[Qwiklabs] Clicking all 'Check my progress' buttons on Qwiklabs UI...", flush=True)
    res = await page.evaluate("""async () => {
      const trackers = Array.from(document.querySelectorAll('ql-activity-tracking'));
      for (const tr of trackers) {
        const shadow = tr.shadowRoot;
        const btn = shadow ? shadow.querySelector('ql-button[aria-label*="progress"], button, ql-button') : null;
        if (btn) btn.click();
      }
      await new Promise(r => setTimeout(r, 5000));
      const updated = trackers.map((tr, idx) => {
        const shadow = tr.shadowRoot;
        const assess = shadow ? shadow.querySelector('ql-assessment') : null;
        const aria = assess ? (assess.getAttribute('aria-label') || '') : '';
        const assessShadow = assess ? assess.shadowRoot : null;
        const passed = Boolean(
          aria.includes('Completed') ||
          aria.includes('passed') ||
          (shadow && shadow.querySelector('.status-icon--complete, [icon="check"]')) ||
          (assessShadow && assessShadow.querySelector('.status-icon--complete, [icon="check"]'))
        );
        return { index: idx + 1, passed, aria };
      });
      const panel = document.querySelector('ql-lab-control-panel');
      const scoreEl = document.querySelector('ql-lab-score, #lab-score') ||
                      (panel && panel.shadowRoot ? panel.shadowRoot.querySelector('ql-lab-score, #lab-score') : null);
      const scoreText = scoreEl ? (scoreEl.shadowRoot ? (scoreEl.shadowRoot.textContent || '') : (scoreEl.textContent || '')).trim() : '';
      return { scoreText, trackers: updated };
    }""")
    print(f"[Qwiklabs] Server-Side UI Tracker Status: {json.dumps(res)}", flush=True)

    if end_lab:
      print("[Qwiklabs] Triggering End Lab...", flush=True)
      await page.evaluate("""async () => {
        if (window.ql && window.ql.labRun) {
          window.ql.labRun.stopLab();
        } else {
          const panel = document.querySelector('ql-lab-control-panel');
          const btn = panel?.shadowRoot?.querySelector('ql-lab-control-button, #lab-control-button');
          if (btn) btn.click();
        }
        await new Promise(r => setTimeout(r, 1200));
        const dialog = document.querySelector('ql-dialog, [role="dialog"]');
        if (dialog) {
          const confirmBtn = dialog.shadowRoot
            ? dialog.shadowRoot.querySelector('ql-button[aria-label*="End"], ql-button[aria-label*="Submit"], [data-qa="confirm-end-lab-button"]')
            : dialog.querySelector('button, ql-button');
          if (confirmBtn) confirmBtn.click();
        }
      }""")
      print("[Qwiklabs] Lab ended cleanly.", flush=True)
    return res


def start_gcloud_no_browser(cmd: list[str]):
  """Spawns `gcloud auth login --no-launch-browser` in a pty and extracts the OAuth URL."""
  master, slave = pty.openpty()
  proc = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave, close_fds=True)
  os.close(slave)
  buf = ""
  deadline = time.time() + 25
  while time.time() < deadline:
    r, _, _ = select.select([master], [], [], 0.3)
    if r:
      chunk = os.read(master, 4096).decode("utf-8", errors="replace")
      buf += chunk
      if "Y/n" in buf or "(Y/n)" in buf:
        os.write(master, b"Y\n")
        buf = ""
      m = re.search(r"(https://accounts\.google\.com/\S+)", buf)
      if m and ("authorization code" in buf.lower() or "verification code" in buf.lower()):
        return proc, master, m.group(1)
  raise RuntimeError("Failed to obtain OAuth URL from gcloud auth login.")


def finish_gcloud_code(proc: subprocess.Popen, master: int, code: str) -> None:
  """Feeds the OAuth authorization code into the waiting gcloud pty."""
  os.write(master, (code.strip() + "\n").encode("utf-8"))
  out = ""
  deadline = time.time() + 30
  while time.time() < deadline:
    r, _, _ = select.select([master], [], [], 0.3)
    if r:
      try:
        out += os.read(master, 4096).decode("utf-8", errors="replace")
      except OSError:
        break
    if proc.poll() is not None:
      break
  proc.wait(timeout=10)
  os.close(master)
  if proc.returncode != 0:
    raise RuntimeError(f"gcloud auth login failed with exit code {proc.returncode}")
  print("[gcloud] Student gcloud CLI + ADC authenticated!", flush=True)


async def authenticate_student_gcloud(
    student_cdp_port: int,
    student_email: str,
    student_password: str,
    sso_url: str,
    project_id: str,
    out_dir: str,
) -> None:
  """Uses the headless student browser (port 19225) to complete `gcloud auth login` unattended."""
  from browser_sso import ensure_chrome_cdp, login_qwiklabs_console

  student_cdp_url = f"http://127.0.0.1:{student_cdp_port}"
  profile_dir = f"/tmp/ql-student-{project_id}"
  ensure_chrome_cdp(student_cdp_port, profile_dir, force_restart=True)

  await login_qwiklabs_console(
      cdp_url=student_cdp_url,
      project_id=project_id,
      sso_url=sso_url,
      student_email=student_email,
      student_password=student_password,
      screenshot_dir=out_dir,
  )

  proc, master, auth_url = start_gcloud_no_browser(
      ["gcloud", "auth", "login", student_email, "--no-launch-browser", "--update-adc", "--quiet"]
  )

  async with async_playwright() as p:
    browser = await p.chromium.connect_over_cdp(student_cdp_url)
    context = browser.contexts[0]
    page = await context.new_page()
    await page.goto(auth_url, wait_until="domcontentloaded", timeout=60000)

    code = ""
    filled_email = False
    filled_pass = False
    clicked_acct = False
    for _ in range(45):
      await page.wait_for_timeout(1500)
      body_text = await page.locator("body").inner_text()
      m = re.search(r"(4/[0-9A-Za-z_\-]{20,})", body_text)
      if m:
        code = m.group(1)
        break

      code_inp = page.locator("input[readonly], textarea[readonly], code").first
      if await code_inp.count() > 0:
        val = (await code_inp.input_value() if await code_inp.evaluate("e => 'value' in e") else await code_inp.inner_text()).strip()
        if val.startswith("4/"):
          code = val
          break

      # Fill password if prompted (check password before email so slide-out animation of email doesn't block password)
      pass_inp = page.locator("input[type='password']:visible, input[name='Passwd']:visible").first
      if not filled_pass and await pass_inp.count() > 0:
        await pass_inp.fill(student_password)
        await pass_inp.press("Enter")
        filled_pass = True
        await page.wait_for_timeout(4500)
        continue

      # Fill email if prompted
      email_inp = page.locator("input[type='email']:visible, #identifierId:visible").first
      if not filled_email and await email_inp.count() > 0:
        if not await email_inp.input_value():
          await email_inp.fill(student_email)
        await email_inp.press("Enter")
        filled_email = True
        await page.wait_for_timeout(3500)
        continue

      # Click Allow / Continue / Sign in consent buttons BEFORE account chooser
      clicked_consent = False
      for label in ("Continue", "Allow", "Authorize", "Sign in", "I understand", "Accept"):
        btn = page.locator(f"button:has-text('{label}'):visible, input[value='{label}']:visible, [role='button']:has-text('{label}'):visible").first
        if await btn.count() > 0:
          await btn.click()
          clicked_consent = True
          await page.wait_for_timeout(2500)
          break
      if clicked_consent:
        continue

      # Click account chooser entry only when on the Choose an Account screen
      acct = page.locator(f"[data-identifier='{student_email}'], [data-identifier]").first
      if not clicked_acct and await acct.count() > 0 and await acct.is_visible():
        if "choose an account" in body_text.lower() or "accountchooser" in page.url.lower():
          await acct.click()
          clicked_acct = True
          await page.wait_for_timeout(3000)
          continue

    await page.close()
    if not code:
      raise RuntimeError("Timed out waiting for OAuth authorization code in headless student browser.")

  finish_gcloud_code(proc, master, code)
  subprocess.run(["gcloud", "config", "set", "project", project_id], check=True)


def parse_details_from_sso_url(sso_url: str) -> tuple[str, str]:
  """Extracts (project_id, student_email) from a Qwiklabs google_sso URL if present."""
  decoded = urllib.parse.unquote(urllib.parse.unquote(sso_url))
  proj_m = re.search(r"(qwiklabs-gcp-[0-9a-f\-]+)", decoded)
  email_m = re.search(r"(student-[0-9a-z\-]+@qwiklabs\.net)", decoded)
  return (proj_m.group(1) if proj_m else "", email_m.group(1) if email_m else "")


def detect_region_via_gcloud(project_id: str) -> str:
  """Detects the provisioned default_region from project metadata or Vertex/Cloud Run resources."""
  try:
    out = subprocess.check_output(
        ["gcloud", "compute", "project-info", "describe", f"--project={project_id}", "--format=value(commonInstanceMetadata.items[google-compute-default-region])"],
        text=True,
        stderr=subprocess.DEVNULL,
    ).strip()
    if out:
      return out
  except Exception:
    pass
  for reg in ("us-central1", "us-east1", "us-east4", "us-west1", "europe-west1", "europe-west4"):
    try:
      out = subprocess.check_output(
          ["gcloud", "run", "services", "list", f"--project={project_id}", f"--region={reg}", "--format=value(metadata.name)"],
          text=True,
          stderr=subprocess.DEVNULL,
      ).strip()
      if out:
        return reg
    except Exception:
      continue
  return "us-central1"


def main() -> int:
  parser = argparse.ArgumentParser(description="Provision Qwiklabs Lab 663130 via Playwright and run E2E suite.")
  parser.add_argument(
      "--lab-url",
      default="https://gcpstaging.qwiklabs.com/labs/663130/edit",
      help="Qwiklabs lab URL (automatically strips /edit to open the Play view)",
  )
  parser.add_argument(
      "--qwiklabs-cdp-url",
      default="http://127.0.0.1:9222",
      help="CDP URL of the Chrome instance logged into gcpstaging.qwiklabs.com",
  )
  parser.add_argument(
      "--student-cdp-port",
      type=int,
      default=19225,
      help="CDP port for the isolated headless student Chrome instance",
  )
  parser.add_argument("--sso-url", default="", help="Optional pre-copied Qwiklabs Google SSO URL")
  parser.add_argument("--student-email", "--username", dest="student_email", default="", help="Optional student email (auto-extracted if omitted)")
  parser.add_argument("--student-password", "--password", "--password-env", dest="student_password", default=os.environ.get("QWIKLABS_PASSWORD", ""), help="Optional student password (auto-extracted from Qwiklabs screen if omitted)")
  parser.add_argument("--project", "--project-id", dest="project", default="", help="Optional GCP project ID (auto-extracted if omitted)")
  parser.add_argument("--region", default="", help="Optional GCP region (auto-extracted if omitted)")
  parser.add_argument("--apigee-host", default="", help="Optional Apigee hostname")
  parser.add_argument(
      "--assessments-dir",
      default="/usr/local/google/home/mtalreja/gcp-enablement-content/labs/enbl080-apigee-ai-agents-workshop/assessments",
      help="Path to Qwiklabs assessment .rb scripts",
  )
  parser.add_argument("--output-dir", default="./artifacts_e2e", help="Directory for E2E screenshots and report.json")
  parser.add_argument("--start-from", default="1", help="Stage to start or resume from (1, 2a, 2b, 2c, 3a, 3a_adk, 3b, 4, 5)")
  parser.add_argument("--student-home", default="", help="Optional existing student home directory to reuse")
  parser.add_argument("--end-lab", action="store_true", help="Automatically click End Lab after 100/100 pass")
  args = parser.parse_args()

  out_dir = os.path.abspath(args.output_dir)
  os.makedirs(out_dir, exist_ok=True)

  used_qwiklabs_cdp = False
  if not args.student_password or not (args.sso_url or args.project):
    used_qwiklabs_cdp = True
    creds = asyncio.run(
        provision_lab_via_playwright(
            qwiklabs_cdp_url=args.qwiklabs_cdp_url,
            lab_url=args.lab_url,
        )
    )
    student_email = args.student_email or creds["username"]
    student_password = args.student_password or creds["password"]
    project_id = args.project or creds["project_id"]
    region = args.region or creds["region"]
    apigee_host = args.apigee_host or creds["apigee_host"]
    sso_url = args.sso_url or creds["sso_url"]
  else:
    sso_proj, sso_email = parse_details_from_sso_url(args.sso_url)
    project_id = args.project or sso_proj
    student_email = args.student_email or sso_email
    student_password = args.student_password
    sso_url = args.sso_url
    region = args.region
    apigee_host = args.apigee_host

  if not re.fullmatch(r"[a-z0-9\-]+", project_id):
    raise ValueError(f"Invalid or missing project_id: {project_id!r}")

  # Step 2: Headless student gcloud auth login + ADC
  cur_acct = subprocess.run(["gcloud", "config", "get-value", "account"], capture_output=True, text=True).stdout.strip()
  if args.start_from != "1" and cur_acct == student_email:
    from browser_sso import ensure_chrome_cdp
    ensure_chrome_cdp(args.student_cdp_port, f"/tmp/ql-student-{project_id}", force_restart=False)
  else:
    asyncio.run(
        authenticate_student_gcloud(
            student_cdp_port=args.student_cdp_port,
            student_email=student_email,
            student_password=student_password,
            sso_url=sso_url,
            project_id=project_id,
            out_dir=out_dir,
        )
    )

  if not region:
    region = detect_region_via_gcloud(project_id)
    print(f"[Auto-Detect] Detected provisioned region: {region}", flush=True)
  if not apigee_host:
    apigee_host = f"api-{project_id}.apiservices.dev"

  # Step 3: Run run_workshop_e2e.py
  script_dir = os.path.dirname(os.path.abspath(__file__))
  runner_py = os.path.join(script_dir, "run_workshop_e2e.py")
  env = os.environ.copy()
  env["QWIKLABS_PASSWORD"] = student_password

  cmd = [
      sys.executable,
      runner_py,
      "--project",
      project_id,
      "--region",
      region,
      "--apigee-host",
      apigee_host,
      "--student-email",
      student_email,
      "--sso-url",
      sso_url,
      "--cdp-port",
      str(args.student_cdp_port),
      "--assessments-dir",
      args.assessments_dir,
      "--output-dir",
      out_dir,
      "--start-from",
      args.start_from,
  ]
  if args.student_home:
    cmd.extend(["--student-home", args.student_home])
  print(f"[Runner] Launching E2E suite for project={project_id}, region={region} ...", flush=True)
  subprocess.run(cmd, env=env, check=True)

  # Step 4: Trigger server-side Qwiklabs UI "Check my progress" buttons if connected to Qwiklabs browser
  if used_qwiklabs_cdp:
    asyncio.run(
        check_qwiklabs_progress_and_optionally_end(
            qwiklabs_cdp_url=args.qwiklabs_cdp_url,
            lab_url=args.lab_url,
            end_lab=args.end_lab,
        )
    )

  return 0


if __name__ == "__main__":
  sys.exit(main())
