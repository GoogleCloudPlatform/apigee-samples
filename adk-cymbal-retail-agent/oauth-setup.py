# Copyright 2025 Google LLC
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

import os
from pathlib import Path
import argparse
import json
from playwright.sync_api import sync_playwright, expect, TimeoutError as PlaywrightTimeout


def create_client(page, project_id, oauth_client_name, redirect_uris):
    print("Navigating to OAuth Client page ...")
    url = f"https://console.cloud.google.com/auth/clients/create?project={project_id}"
    page.goto(url)
    page.wait_for_url(url)

    # App Information
    print("Selecting application type ...")
    page.get_by_role("combobox", name="Application type").locator("svg").click()
    page.get_by_role("option", name="Web application").click()

    # Contact Info
    print("Entering app name ...")
    page.get_by_role("textbox", name="Name").click()
    page.get_by_role("textbox", name="Name").fill(oauth_client_name)

    # Redirect URI
    print("Entering Redirect URIs name ...")
    for i in range(len(redirect_uris)):
        print(f"Entering  Redirect URI #{i} ...")
        page.locator("[formarrayname=\"redirectUris\"] button", has_text="Add URI").first.click()
        page.get_by_role("textbox", name=f"URIs {i+1}").click()
        page.get_by_role("textbox", name=f"URIs {i+1}").fill(redirect_uris[i])


    # Create
    print(f"Clicking create button ...")
    page.get_by_role("button", name="Create").click()

    print(f"Waiting OAuth Client created dialog ...")
    oauth_dialog = page.get_by_text("OAuth client created").first
    oauth_dialog.wait_for()

    print(f"Clicking OK button ...")
    page.get_by_role("button", name="OK").last.click()

    print(f"Selecting new App name from list ...")
    page.get_by_role("link", name=f"{oauth_client_name}").first.click()

    print(f"Downloading client.json ...")
    with page.expect_download() as download_info:
        page.get_by_role("button", name="Download JSON").last.click()

    download = download_info.value
    download.save_as("client.json")

    print(f"Saving client.json ...")
    with open("client.json", "r", encoding="utf-8") as f:
        data = json.load(f)
        client_id = data["web"]["client_id"]
        client_secret = data["web"]["client_secret"]


    return client_id, client_secret


def create_branding(page, project_id, app_name, support_email, contact_email):
    print("Navigating to branding page ...")
    url = f"https://console.cloud.google.com/auth/overview/create?project={project_id}"
    page.goto(url)
    page.wait_for_url(url)
    page.wait_for_timeout(5000)

    if not page.get_by_role("textbox", name="App name").is_visible():
        return

    print("Entering app name ...")
    # App Information
    page.get_by_role("textbox", name="App name").click()
    page.get_by_role("textbox", name="App name").fill(app_name)
    print("Entering support email ...")
    page.get_by_role("combobox", name="User support email").locator("svg").click()
    page.get_by_role("option", name=support_email).click()
    page.get_by_role("button", name="Next").click()
    print("Checking internal box ...")
    page.get_by_role("radio", name="Internal").click()
    page.get_by_role("button", name="Next").click()
    print("Entering contact email ...")
    page.get_by_role("textbox", name="Email").click()
    page.get_by_role("textbox", name="Email").fill(contact_email)
    page.get_by_role("button", name="Next").click()
    print("Click I agree checkbox ...")
    page.get_by_role("checkbox", name="I agree").click()
    page.get_by_role("button", name="Continue").click()
    print("Clicking Create ...")
    page.get_by_role("button", name="Create").click()

def login(page, project_id, username, password):
    print("Navigating to Sign in page ...")
    url = f"https://console.cloud.google.com/welcome?project={project_id}"
    page.goto(url)

    try:
        page.locator("span", has_text="Sign in").wait_for(timeout=5000)
    except PlaywrightTimeout:
        pass

    if page.locator("span", has_text="Sign in").is_visible():
        print("Entering username ...")
        page.get_by_role("textbox", name="Email or phone").click()
        page.get_by_role("textbox", name="Email or phone").fill(username)
        page.get_by_role("button", name="Next").click()
        print("Entering password ...")
        page.get_by_role("textbox", name="Enter your password").click()
        page.get_by_role("textbox", name="Enter your password").fill(password)
        page.get_by_role("button", name="Next").click()



    # TOS #1
    try:
        page.locator("input", has_text="understand").wait_for(timeout=5000)
    except PlaywrightTimeout:
        pass

    if page.locator("input", has_text="understand").is_visible():
        print("Clicking I understand ...")
        page.get_by_role("button", name="understand").click()


    # TOS #2
    try:
        page.get_by_role("checkbox", name="I agree to").wait_for(timeout=5000)
    except PlaywrightTimeout:
        pass

    if page.get_by_role("checkbox", name="I agree to").is_visible():
        print("Clicking I Agree checkbox ...")
        page.get_by_role("checkbox", name="I agree to").check()
        print("Clicking Agree and continue ...")
        page.get_by_role("button", name="Agree and continue").click()

    print("Sign in complete ...")

def get_browser(pw):
    home_dir = Path.home()
    os.makedirs(f"{os.getcwd()}/.playwright/videos", exist_ok=True)
    os.makedirs(f"{os.getcwd()}/.playwright/chrome", exist_ok=True)
    browser_context = pw.chromium.launch_persistent_context(
        user_data_dir=f"{os.getcwd()}/.playwright/chrome",
        headless=True,
        accept_downloads=True,
        downloads_path=os.getcwd(),
        user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36",
        args = [
            "--disable-blink-features=AutomationControlled",
            "--disable-search-engine-choice-screen",
            "--disable-gpu",
            "--window-size=1024,768",
            "-no-sandbox"
        ],
        ignore_default_args=["--enable-automation"],
        record_video_dir=f"{os.getcwd()}/.playwright/videos",
    )

    return browser_context


def read_args():

    parser = argparse.ArgumentParser()
    project_id = os.getenv("PROJECT_ID") or None
    if not project_id:
        parser.add_argument('--project-id', help='GCP Project ID', required=True)

    username = os.getenv("USERNAME") or None
    if not username:
        parser.add_argument('--username', help='GCP username', required=True)

    password = os.getenv("PASSWORD") or None
    if not password:
        parser.add_argument('--password', help='GCP password', required=True)

    branding_app_name = os.getenv("BRANDING_APP_NAME") or None
    if not branding_app_name:
        parser.add_argument('--branding-app-name', help='Branding application name', required=True)

    oauth_client_name = os.getenv("OAUTH_CLIENT_NAME") or None
    if not oauth_client_name:
        parser.add_argument('--oauth-client-name', help='OAuth client application name', required=True)


    oauth_redirect_uris = os.getenv("OAUTH_REDIRECT_URIS") or None
    if oauth_redirect_uris:
        oauth_redirect_uris = oauth_redirect_uris.split(",")
    else:
        parser.add_argument('--oauth-redirect-uris', nargs='+', help='OAuth Redirect URIs', required=True)


    args = parser.parse_args()
    params = {
        "project_id": project_id if project_id else args.project_id,
        "username": username if username else args.username,
        "password": password if password else args.password,
        "branding_app_name": branding_app_name if branding_app_name else args.branding_app_name,
        "oauth_client_name": oauth_client_name if oauth_client_name else args.oauth_client_name,
        "oauth_redirect_uris": oauth_redirect_uris if oauth_client_name else args.oauth_redirect_uris
    }

    return params

def main() :

    args = read_args()
    print(args)

    with sync_playwright() as pw:
        browser = get_browser(pw)
        page = browser.new_page()

        login(page, args["project_id"], args["username"], args["password"])
        create_branding(page, args["project_id"], args["branding_app_name"], args["username"], args["username"])
        client_id, client_secret = create_client(page, args["project_id"], args["oauth_client_name"], args["oauth_redirect_uris"])
        browser.close()

    with open("oauth_client_env.sh", "w") as file:
        file.write(f"""
OAUTH_CLIENT_ID={client_id}
OAUTH_CLIENT_SECRET={client_secret}
export OAUTH_CLIENT_ID
export OAUTH_CLIENT_SECRET""")

main()