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

"""Headless Chrome CDP browser manager and Qwiklabs Google Cloud SSO helper."""

import asyncio
import os
import subprocess
import tempfile
import time
import urllib.request
from playwright.async_api import async_playwright


def ensure_chrome_cdp(cdp_port: int = 19225, profile_dir: str | None = None) -> subprocess.Popen | None:
  """Ensure a headless Chrome instance is listening on the given CDP port."""
  cdp_url = f"http://127.0.0.1:{cdp_port}/json/version"
  try:
    with urllib.request.urlopen(cdp_url, timeout=2) as resp:
      if resp.status == 200:
        return None
  except Exception:
    pass

  if not profile_dir:
    profile_dir = tempfile.mkdtemp(prefix="ql_pw_chrome_")
  os.makedirs(profile_dir, exist_ok=True)
  empty_pol = tempfile.mkdtemp(prefix="empty_chrome_pol_")

  proc_env = os.environ.copy()
  proc_env["PW_EMPTY_POL"] = os.path.realpath(empty_pol)
  proc_env["PW_PROFILE_DIR"] = os.path.realpath(profile_dir)
  proc_env["PW_CDP_PORT"] = str(int(cdp_port))

  cmd = [
      "unshare",
      "-r",
      "-m",
      "bash",
      "-c",
      (
          'mount --bind "$PW_EMPTY_POL" /etc/opt/chrome/policies 2>/dev/null || true; '
          'exec google-chrome --headless=new --no-sandbox --disable-dev-shm-usage '
          '--disable-gpu --password-store=basic --disable-popup-blocking '
          '--window-size=1440,950 --user-data-dir="$PW_PROFILE_DIR" '
          '--remote-debugging-port="$PW_CDP_PORT" about:blank'
      ),
  ]
  proc = subprocess.Popen(cmd, env=proc_env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=os.setsid)
  for _ in range(30):
    try:
      with urllib.request.urlopen(cdp_url, timeout=2) as resp:
        if resp.status == 200:
          return proc
    except Exception:
      time.sleep(0.5)
  raise RuntimeError(f"Failed to start headless Chrome CDP server on port {cdp_port}")


async def login_qwiklabs_console(
    cdp_url: str,
    project_id: str,
    sso_url: str | None = None,
    student_email: str | None = None,
    student_password: str | None = None,
    screenshot_dir: str = ".",
) -> None:
  """Authenticate browser session into Google Cloud Console for the lab project."""
  async with async_playwright() as p:
    browser = await p.chromium.connect_over_cdp(cdp_url)
    context = browser.contexts[0]
    page = await context.new_page()
    await page.set_viewport_size({"width": 1440, "height": 950})

    target_url = sso_url or f"https://console.cloud.google.com/home/dashboard?project={project_id}"
    await page.goto(target_url, wait_until="domcontentloaded", timeout=60000)
    await page.wait_for_timeout(4000)

    if student_email and await page.locator("input[type='email']:visible").count() > 0:
      email_box = page.locator("input[type='email']:visible").first
      if not await email_box.input_value():
        await email_box.fill(student_email)
      await email_box.press("Enter")
      await page.wait_for_timeout(3500)

    if student_password and await page.locator("input[type='password']:visible").count() > 0:
      pwd_box = page.locator("input[type='password']:visible").first
      await pwd_box.fill(student_password)
      await pwd_box.press("Enter")
      await page.wait_for_timeout(5000)

    # Dismiss Workspace welcome / speedbump screens if shown
    for btn_label in ("I understand", "Accept", "Continue", "Confirm"):
      btn = page.locator(f"button:has-text('{btn_label}'):visible, input[value='{btn_label}']:visible")
      if await btn.count() > 0:
        await btn.first.click()
        await page.wait_for_timeout(3000)

    await page.goto(
        f"https://console.cloud.google.com/home/dashboard?project={project_id}",
        wait_until="domcontentloaded",
        timeout=60000,
    )
    await page.wait_for_timeout(8000)

    # Accept Cloud Console Terms of Service modal if first login
    tos_cb = page.locator("mat-checkbox:has-text('Terms of Service') input[type='checkbox'], input[type='checkbox']")
    agree_btn = page.locator("button:has-text('Agree and continue'):visible")
    if await agree_btn.count() > 0 and await tos_cb.count() > 0:
      await tos_cb.first.check(force=True)
      await page.wait_for_timeout(800)
      await agree_btn.first.click()
      await page.wait_for_timeout(3000)

    os.makedirs(screenshot_dir, exist_ok=True)
    await page.screenshot(path=os.path.join(screenshot_dir, "00_console_dashboard.png"))
    await page.close()
