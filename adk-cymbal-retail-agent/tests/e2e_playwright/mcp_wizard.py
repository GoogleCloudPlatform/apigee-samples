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

"""Playwright UI driver for Apigee API Hub 'Configure MCP tools' 3-step wizard."""

import json
import os
import subprocess
import time
import urllib.request
from playwright.async_api import async_playwright


def ensure_apihub_plugin_and_specs(project_id: str, region: str) -> None:
  """Ensure system-apigee-x-and-hybrid plugin & OpenAPI specs exist on cymbal-*-v2 versions."""
  def _tok() -> str:
    return subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()

  def _req(method: str, url: str, body=None):
    hdr = {"Authorization": f"Bearer {_tok()}", "Content-Type": "application/json"}
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, headers=hdr, method=method)
    with urllib.request.urlopen(r, timeout=30) as resp:
      return json.loads(resp.read().decode())

  try:
    _req(
        "POST",
        f"https://apihub.googleapis.com/v1/projects/{project_id}/locations/{region}/plugins/system-apigee-x-and-hybrid/instances?pluginInstanceId={project_id}",
        {
            "displayName": f"Apigee X and Hybrid - {project_id}",
            "sourceProjectId": project_id,
            "actions": [{"actionId": "sync-metadata"}, {"actionId": "sync-runtime-data"}],
        },
    )
  except Exception:
    pass

  targets = {
      "cymbal-orders-v2": ("orders_api", "orders.yaml"),
      "cymbal-returns-v2": ("returns_api", "returns.yaml"),
      "cymbal-customers-v2": ("customers_api", "customers.yaml"),
      "cymbal-shipping-v2": ("shipping_api", "shipping.yaml"),
  }
  synced = set()
  for _ in range(18):
    apis = _req("GET", f"https://apihub.googleapis.com/v1/projects/{project_id}/locations/{region}/apis?pageSize=100").get("apis", [])
    by_display = {a.get("displayName"): a.get("name") for a in apis if a.get("name") and not a["name"].endswith("_api")}
    for proxy_name, (src_api_id, spec_display) in targets.items():
      if proxy_name in synced or proxy_name not in by_display:
        continue
      try:
        src_contents = _req(
            "GET",
            f"https://apihub.googleapis.com/v1/projects/{project_id}/locations/{region}/apis/{src_api_id}/versions/1_0_0/specs/1_0_0:contents",
        )
        vers = _req("GET", f"https://apihub.googleapis.com/v1/{by_display[proxy_name]}/versions").get("versions", [])
        if not vers:
          continue
        ver_name = vers[0]["name"]
        existing = _req("GET", f"https://apihub.googleapis.com/v1/{ver_name}/specs").get("specs", [])
        if not existing:
          _req(
              "POST",
              f"https://apihub.googleapis.com/v1/{ver_name}/specs?specId=openapi",
              {
                  "displayName": spec_display,
                  "specType": {"enumValues": {"values": [{"id": "openapi"}]}},
                  "parsingMode": "RELAXED",
                  "contents": {
                      "contents": src_contents["contents"],
                      "mimeType": src_contents.get("mimeType", "application/yaml"),
                  },
              },
          )
        synced.add(proxy_name)
      except Exception:
        pass
    if len(synced) == len(targets):
      break
    time.sleep(5)


async def _pick_select(page, sel, label: str, target_substr: str) -> None:
  await sel.scroll_into_view_if_needed()
  box = await sel.bounding_box()
  await page.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
  await page.wait_for_timeout(1800)

  overlay_items = await page.evaluate("""() => {
    const panes = Array.from(document.querySelectorAll('.cdk-overlay-pane'));
    if (!panes.length) return [];
    const topPane = panes[panes.length - 1];
    return Array.from(topPane.querySelectorAll('*'))
      .filter(e => e.children.length === 0 && (e.innerText || '').trim().length > 0 && e.getBoundingClientRect().height > 0 && !['Filter', 'Cancel', 'OK'].includes(e.innerText.trim()))
      .map(e => { const r = e.getBoundingClientRect(); return {text: e.innerText.trim(), x: r.left + r.width/2, y: r.top + r.height/2}; });
  }""")
  picked = next((i for i in overlay_items if target_substr.lower() in i["text"].lower()), None)
  if not picked:
    raise RuntimeError(f"Could not find option matching {target_substr!r} for {label} in {[i['text'] for i in overlay_items]}")

  await page.mouse.click(picked["x"], picked["y"])
  await page.wait_for_timeout(1200)

  ok_item = await page.evaluate("""() => {
    const panes = Array.from(document.querySelectorAll('.cdk-overlay-pane'));
    if (!panes.length) return null;
    const topPane = panes[panes.length - 1];
    const hit = Array.from(topPane.querySelectorAll('*'))
      .find(e => e.children.length === 0 && (e.innerText || '').trim() === 'OK' && e.getBoundingClientRect().height > 0);
    if (!hit) return null;
    const r = hit.getBoundingClientRect();
    return {x: r.left + r.width / 2, y: r.top + r.height / 2};
  }""")
  if ok_item:
    await page.mouse.click(ok_item["x"], ok_item["y"])
    await page.wait_for_timeout(1500)


async def _add_one_api_in_step2(page, api_display_name: str, screenshot_dir: str, shot_tag: str) -> None:
  await page.locator("button:has-text('Add tools'):visible").first.click()
  await page.wait_for_timeout(2500)
  drawer_selects = page.locator("cfc-select:visible")
  base = (await drawer_selects.count()) - 4
  await _pick_select(page, drawer_selects.nth(base + 0), f"API ({api_display_name})", api_display_name)
  await _pick_select(page, drawer_selects.nth(base + 1), "Version", "")
  await _pick_select(page, drawer_selects.nth(base + 2), "Deployment", "")
  await _pick_select(page, drawer_selects.nth(base + 3), "Specification", "")
  await page.wait_for_timeout(2500)

  targets = await page.evaluate("""() => {
    const opTh = Array.from(document.querySelectorAll('th'))
      .find(e => (e.innerText || '').trim() === 'Operation path' && e.getBoundingClientRect().width > 0);
    if (!opTh || !opTh.previousElementSibling) return null;
    const cbRect = opTh.previousElementSibling.getBoundingClientRect();
    const addBtn = Array.from(document.querySelectorAll('button'))
      .find(b => (b.innerText || '').trim() === 'Add' && b.getBoundingClientRect().left > 800 && b.getBoundingClientRect().height > 0);
    if (!addBtn) return null;
    const addRect = addBtn.getBoundingClientRect();
    return {
      cb: {x: cbRect.left + cbRect.width / 2, y: cbRect.top + cbRect.height / 2},
      add: {x: addRect.left + addRect.width / 2, y: addRect.top + addRect.height / 2}
    };
  }""")
  if not targets:
    raise RuntimeError(f"Could not find select-all checkbox / Add button for {api_display_name}")

  await page.mouse.click(targets["cb"]["x"], targets["cb"]["y"])
  await page.wait_for_timeout(1000)
  await page.screenshot(path=os.path.join(screenshot_dir, f"mcp_ops_{shot_tag}.png"))
  await page.mouse.click(targets["add"]["x"], targets["add"]["y"])
  await page.wait_for_timeout(2500)


async def configure_mcp_proxy_ui(
    cdp_url: str,
    project_id: str,
    api_names: list[str],
    screenshot_dir: str,
    shot_prefix: str,
    proxy_name: str = "cymbal-discovery-v1",
    env_group: str = "eval-group",
    env_name: str = "eval",
    edit_mode: bool = False,
) -> None:
  """Create or edit an MCP Discovery proxy via the Google Cloud Console API Hub wizard."""
  os.makedirs(screenshot_dir, exist_ok=True)
  async with async_playwright() as p:
    browser = await p.chromium.connect_over_cdp(cdp_url)
    page = await browser.contexts[0].new_page()
    await page.set_viewport_size({"width": 1440, "height": 950})
    await page.goto(f"https://console.cloud.google.com/apigee/api-hub/apis?project={project_id}", wait_until="domcontentloaded", timeout=60000)
    await page.wait_for_timeout(8000)

    if edit_mode:
      href = await page.locator(f"a:has-text('{proxy_name}')").first.get_attribute("href")
      if not href:
        raise RuntimeError(f"Could not find {proxy_name} link on API Hub APIs page")
      await page.goto(f"https://console.cloud.google.com{href}", wait_until="domcontentloaded", timeout=60000)
      await page.wait_for_timeout(6000)
      await page.locator("button:has-text('Configure MCP tools'), a:has-text('Configure MCP tools'), [role='tab']:has-text('Configure MCP tools')").first.click(force=True)
      await page.wait_for_timeout(4000)
      await page.locator("button:has-text('Edit MCP tools'), a:has-text('Edit MCP tools')").first.click(force=True)
      await page.wait_for_timeout(5000)
    else:
      await page.locator("button:has-text('Configure MCP tools'), a:has-text('Configure MCP tools')").first.click()
      await page.wait_for_timeout(5000)
      await _pick_select(page, page.locator("cfc-select:visible").nth(0), "Runtime project", project_id)
      await _pick_select(page, page.locator("cfc-select:visible").nth(1), "Environment group", env_group)
      await page.wait_for_timeout(2500)
      name_inp = page.locator("input[type='text']:visible, input:not([type]):visible")
      for idx in range(await name_inp.count()):
        ph = await name_inp.nth(idx).get_attribute("placeholder") or ""
        if "Search" not in ph:
          if not await name_inp.nth(idx).input_value():
            await name_inp.nth(idx).fill(proxy_name)
          break
      await page.wait_for_timeout(800)
      dep_sel = page.locator("cfc-select:visible").nth(2)
      if env_name not in (await dep_sel.inner_text()).lower():
        await _pick_select(page, dep_sel, "Deployment environment", env_name)

    await page.screenshot(path=os.path.join(screenshot_dir, f"{shot_prefix}_step1.png"))
    await page.locator("button:has-text('Continue'):visible").first.click()
    await page.wait_for_timeout(2500)

    for i, api_name in enumerate(api_names, start=1):
      await _add_one_api_in_step2(page, api_name, screenshot_dir, f"{shot_prefix}_{i}")

    await page.screenshot(path=os.path.join(screenshot_dir, f"{shot_prefix}_step2.png"))
    await page.locator("button:has-text('Continue'):visible").first.click()
    await page.wait_for_timeout(2000)
    await page.screenshot(path=os.path.join(screenshot_dir, f"{shot_prefix}_step3.png"))
    await page.locator("button:has-text('Deploy'):visible").first.click()
    await page.wait_for_timeout(8000)
    await page.close()
