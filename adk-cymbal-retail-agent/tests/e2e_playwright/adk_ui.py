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

"""Playwright UI driver and process lifecycle manager for Google ADK Web."""

import os
import signal
import subprocess
import time
import urllib.request
from playwright.async_api import async_playwright


class AdkWebServer:
  """Manages local `uv run adk web` server bound strictly to 127.0.0.1."""

  def __init__(self, port: int = 8000, student_home: str | None = None):
    self.port = int(port)
    self.student_home = student_home
    self.proc: subprocess.Popen | None = None

  @property
  def url(self) -> str:
    return f"http://127.0.0.1:{self.port}"

  def restart(self, agent_parent_dir: str) -> None:
    self.stop()
    env = os.environ.copy()
    orig_local_bin = os.path.expanduser("~/.local/bin")
    if self.student_home:
      real_home = os.path.realpath(self.student_home)
      env["HOME"] = real_home
      env["PATH"] = f"{real_home}/.local/bin:{real_home}/.apigeecli/bin:{orig_local_bin}:" + env.get("PATH", "")
    self.proc = subprocess.Popen(
        [
            "uv",
            "run",
            "adk",
            "web",
            "--host",
            "127.0.0.1",
            "--port",
            str(self.port),
            "--allow_origins=*",
            ".",
        ],
        cwd=os.path.realpath(agent_parent_dir),
        env=env,
        preexec_fn=os.setsid,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(35):
      try:
        with urllib.request.urlopen(self.url, timeout=2) as resp:
          if resp.status == 200:
            return
      except Exception:
        time.sleep(1)
    raise RuntimeError(f"ADK Web failed to become healthy at {self.url}")

  def stop(self) -> None:
    if self.proc and self.proc.poll() is None:
      os.killpg(os.getpgid(self.proc.pid), signal.SIGTERM)
      try:
        self.proc.wait(timeout=5)
      except Exception:
        os.killpg(os.getpgid(self.proc.pid), signal.SIGKILL)
      self.proc = None
    subprocess.run(["fuser", "-k", f"{self.port}/tcp"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


async def send_adk_prompts(
    cdp_url: str,
    adk_url: str,
    prompts: list[str],
    screenshot_dir: str,
    screenshot_prefix: str,
    timeout_sec: int = 90,
) -> list[dict]:
  """Send prompts in ADK Web UI via Playwright, handling 3-legged OAuth popups automatically."""
  os.makedirs(screenshot_dir, exist_ok=True)
  async with async_playwright() as p:
    browser = await p.chromium.connect_over_cdp(cdp_url)
    context = browser.contexts[0]
    popup_urls: list[str] = []
    context.on("page", lambda popup: popup_urls.append(popup.url))

    page = await context.new_page()
    await page.set_viewport_size({"width": 1440, "height": 950})
    await page.goto(adk_url, wait_until="networkidle", timeout=60000)
    await page.wait_for_timeout(2000)

    backdrop = page.locator(".mat-drawer-backdrop.mat-drawer-shown")
    if await backdrop.count() > 0:
      await page.keyboard.press("Escape")
      await page.wait_for_timeout(500)

    results = []
    for idx, prompt in enumerate(prompts, start=1):
      print(f"[ADK UI | {screenshot_prefix}] Sending prompt #{idx}: {prompt!r}", flush=True)
      before_text = await page.locator("body").inner_text()
      box = page.locator("textarea.chat-input-box, textarea:visible, input[type='text']:visible").last
      await box.wait_for(state="visible", timeout=20000)
      await box.click(force=True)
      await box.fill(prompt)
      await box.press("Enter")

      reply_snippet = ""
      t0 = time.time()
      stable_ticks = 0
      last_body = before_text
      while time.time() - t0 < timeout_sec:
        await page.wait_for_timeout(1500)
        auth_btns = page.locator("button:has-text('Sign in'), button:has-text('Authenticate'), button:has-text('Authorize'), a:has-text('Sign in')")
        for b_idx in range(await auth_btns.count()):
          btn = auth_btns.nth(b_idx)
          if await btn.is_visible():
            print(f"[ADK UI | {screenshot_prefix}] Clicking OAuth button: {await btn.inner_text()!r}", flush=True)
            await btn.click()
            await page.wait_for_timeout(2500)

        body_now = await page.locator("body").inner_text()
        if body_now != before_text:
          still_streaming = ("\nstop\n" in body_now or body_now.endswith("\nstop") or "Sending" in body_now or "Thinking" in body_now)
          if body_now == last_body and not still_streaming:
            stable_ticks += 1
            if stable_ticks >= 2:
              pos = body_now.rfind(prompt)
              reply_snippet = body_now[pos:] if pos >= 0 else body_now[-600:]
              break
          else:
            stable_ticks = 0
        last_body = body_now

      shot_path = os.path.join(screenshot_dir, f"{screenshot_prefix}_p{idx}.png")
      await page.screenshot(path=shot_path, full_page=False)
      elapsed = round(time.time() - t0, 2)
      print(f"[ADK UI | {screenshot_prefix}] Reply #{idx} ({elapsed}s):\n{reply_snippet[:450]}\n[Screenshot -> {shot_path}]", flush=True)
      results.append({
          "prompt": prompt,
          "elapsed_sec": elapsed,
          "reply": reply_snippet,
          "screenshot": shot_path,
          "oauth_popups": list(popup_urls),
      })

    await page.close()
    return results
