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


def ensure_chrome_cdp(cdp_port: int = 19225, profile_dir: str | None = None, force_restart: bool = False) -> subprocess.Popen | None:
  """Ensure a headless Chrome instance is listening on the given CDP port."""
  cdp_url = f"http://127.0.0.1:{cdp_port}/json/version"
  if force_restart:
    subprocess.run(["fuser", "-k", f"{cdp_port}/tcp"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    time.sleep(1)
  else:
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
          '--disable-blink-features=AutomationControlled '
          '--user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" '
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

    # If already logged into Cloud Console in this browser context, reuse the session
    already_authed = False
    if os.path.exists(os.path.join(screenshot_dir, "00_console_dashboard.png")):
      await page.goto(
          f"https://console.cloud.google.com/home/dashboard?project={project_id}",
          wait_until="domcontentloaded",
          timeout=60000,
      )
      await page.wait_for_timeout(4000)
      if "console.cloud.google.com" in page.url and "accounts.google.com" not in page.url:
        already_authed = True

    if not already_authed:
      target_url = sso_url or f"https://console.cloud.google.com/home/dashboard?project={project_id}"
      await page.goto(target_url, wait_until="domcontentloaded", timeout=60000)
      await page.wait_for_timeout(3500)

      filled_email = False
      filled_pwd = False
      clicked_acct = False
      for _ in range(15):
        if "console.cloud.google.com" in page.url and "accounts.google.com" not in page.url and "qwiklabs.com" not in page.url:
          break

        if student_password and not filled_pwd and await page.locator("input[type='password']:visible, input[name='Passwd']:visible").count() > 0:
          pwd_box = page.locator("input[type='password']:visible, input[name='Passwd']:visible").first
          await pwd_box.fill(student_password)
          await pwd_box.press("Enter")
          filled_pwd = True
          await page.wait_for_timeout(4500)
          continue

        if student_email and not filled_email and await page.locator("input[type='email']:visible, #identifierId:visible").count() > 0:
          email_box = page.locator("input[type='email']:visible, #identifierId:visible").first
          if not await email_box.input_value():
            await email_box.fill(student_email)
          await email_box.press("Enter")
          filled_email = True
          await page.wait_for_timeout(3500)
          continue

        if "accounts.google.com" in page.url:
          clicked_bump = False
          for btn_label in ("Continue", "I understand", "Accept", "Confirm"):
            btn = page.locator(f"button:has-text('{btn_label}'):visible, input[value='{btn_label}']:visible, [role='button']:has-text('{btn_label}'):visible")
            if await btn.count() > 0 and await btn.first.is_enabled():
              await btn.first.click()
              clicked_bump = True
              await page.wait_for_timeout(3500)
              break
          if clicked_bump:
            continue

          acct = page.locator(f"[data-identifier='{student_email}'], [data-identifier]").first
          if not clicked_acct and await acct.count() > 0 and await acct.is_visible():
            body_txt = (await page.locator("body").inner_text()).lower()
            if "choose an account" in body_txt or "accountchooser" in page.url.lower():
              await acct.click()
              clicked_acct = True
              await page.wait_for_timeout(3000)
              continue

        await page.wait_for_timeout(1500)

    await page.goto(
        f"https://console.cloud.google.com/home/dashboard?project={project_id}",
        wait_until="domcontentloaded",
        timeout=60000,
    )
    await page.wait_for_timeout(8000)

    # Accept Cloud Console Terms of Service modal (including Country select if blank)
    agree_btn = page.locator("button:has-text('Agree and continue'):visible")
    if await agree_btn.count() > 0:
      country_sel = page.locator("mat-dialog-container mat-select, .cdk-overlay-pane mat-select, mat-dialog-container [role='combobox'], .cdk-overlay-pane [role='combobox']")
      if await country_sel.count() > 0:
        await country_sel.first.click()
        await page.wait_for_timeout(1500)
        us_opt = page.locator("mat-option:has-text('United States'), [role='option']:has-text('United States')")
        if await us_opt.count() > 0:
          await us_opt.first.click()
        else:
          await page.locator("mat-option, [role='option']").first.click()
        await page.wait_for_timeout(1000)
      await page.evaluate("""() => {
        const cbs = document.querySelectorAll('.cdk-overlay-pane input[type="checkbox"], mat-dialog-container input[type="checkbox"]');
        cbs.forEach(cb => { if (!cb.checked) cb.click(); });
      }""")
      await page.wait_for_timeout(1000)
      try:
        await agree_btn.first.click(timeout=5000)
        await page.wait_for_timeout(3000)
      except Exception:
        await page.keyboard.press("Escape")

    cookie_btn = page.locator("button:has-text('OK, got it'):visible, #glue-cookie-notification-bar-1 button:visible")
    if await cookie_btn.count() > 0:
      await cookie_btn.first.click(force=True)
      await page.wait_for_timeout(1000)

    os.makedirs(screenshot_dir, exist_ok=True)
    await page.screenshot(path=os.path.join(screenshot_dir, "00_console_dashboard.png"))
    await page.close()
