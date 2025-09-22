import os
from pathlib import Path
import argparse
import json
from playwright.sync_api import sync_playwright, expect, TimeoutError as PlaywrightTimeout


def create_client(page, project_id, oauth_client_name, redirect_uris):
    url = f"https://console.cloud.google.com/auth/clients/create?project={project_id}"
    page.goto(url)
    page.wait_for_url(url)

    # App Information
    page.get_by_role("combobox", name="Application type").locator("svg").click()
    page.get_by_role("option", name="Web application").click()

    # Contact Info
    page.get_by_role("textbox", name="Name").click()
    page.get_by_role("textbox", name="Name").fill(oauth_client_name)

    # Redirect URI
    for i in range(len(redirect_uris)):
        page.locator("[formarrayname=\"redirectUris\"] button", has_text="Add URI").first.click()
        page.get_by_role("textbox", name=f"URIs {i+1}").click()
        page.get_by_role("textbox", name=f"URIs {i+1}").fill(redirect_uris[i])


    # Create
    page.get_by_role("button", name="Create").click()

    oauth_dialog = page.get_by_text("OAuth client created").first
    oauth_dialog.wait_for()

    page.get_by_role("button", name="OK").last.click()
    page.get_by_role("link", name=f"{oauth_client_name}").first.click()

    with page.expect_download() as download_info:
        page.get_by_role("button", name="Download JSON").last.click()

    download = download_info.value
    download.save_as("client.json")

    with open("client.json", "r", encoding="utf-8") as f:
        data = json.load(f)
        client_id = data["web"]["client_id"]
        client_secret = data["web"]["client_secret"]


    return client_id, client_secret


def create_branding(page, project_id, app_name, support_email, contact_email):
    url = f"https://console.cloud.google.com/auth/overview/create?project={project_id}"
    page.goto(url)
    page.wait_for_url(url)
    page.wait_for_timeout(5000)

    if not page.get_by_role("textbox", name="App name").is_visible():
        return

    # App Information
    page.get_by_role("textbox", name="App name").click()
    page.get_by_role("textbox", name="App name").fill(app_name)
    page.get_by_role("combobox", name="User support email").locator("svg").click()
    page.get_by_role("option", name=support_email).click()
    page.get_by_role("button", name="Next").click()
    # Audience
    page.get_by_role("radio", name="Internal").click()
    page.get_by_role("button", name="Next").click()
    # Contact Info
    page.get_by_role("textbox", name="Email").click()
    page.get_by_role("textbox", name="Email").fill(contact_email)
    page.get_by_role("button", name="Next").click()
    # Finish
    page.get_by_role("checkbox", name="I agree").click()
    page.get_by_role("button", name="Continue").click()
    # Create
    page.get_by_role("button", name="Create").click()

def login(page, project_id, username, password):
    url = f"https://console.cloud.google.com/welcome?project={project_id}"
    page.goto(url)

    try:
        page.locator("span", has_text="Sign in").wait_for(timeout=5000)
    except PlaywrightTimeout:
        pass

    if page.locator("span", has_text="Sign in").is_visible():
        page.get_by_role("textbox", name="Email or phone").click()
        page.get_by_role("textbox", name="Email or phone").fill(username)
        page.get_by_role("button", name="Next").click()
        page.get_by_role("textbox", name="Enter your password").click()
        page.get_by_role("textbox", name="Enter your password").fill(password)
        page.get_by_role("button", name="Next").click()



    # TOS #1
    try:
        page.locator("input", has_text="understand").wait_for(timeout=5000)
    except PlaywrightTimeout:
        pass

    if page.locator("input", has_text="understand").is_visible():
        page.get_by_role("button", name="understand").click()


    # TOS #2
    try:
        page.get_by_role("checkbox", name="I agree to").wait_for(timeout=5000)
    except PlaywrightTimeout:
        pass

    if page.get_by_role("checkbox", name="I agree to").is_visible():
        page.get_by_role("checkbox", name="I agree to").check()
        page.get_by_role("button", name="Agree and continue").click()

def get_browser(pw):
    home_dir = Path.home()
    os.makedirs(f"{os.getcwd()}/.playwright/videos", exist_ok=True)
    os.makedirs(f"{os.getcwd()}/.playwright/chrome", exist_ok=True)
    browser_context = pw.chromium.launch_persistent_context(
        user_data_dir=f"{os.getcwd()}/.playwright/chrome",
        headless=True,
        accept_downloads=True,
        downloads_path=os.getcwd(),
        args = ["--disable-blink-features=AutomationControlled"],
        ignore_default_args=["--enable-automation"],
        record_video_dir=f"{os.getcwd()}/.playwright/videos",
    )

    return browser_context


def read_args():

    parser = argparse.ArgumentParser()
    parser.add_argument('--project-id', help='GCP Project ID', required=True)
    parser.add_argument('--username', help='GCP username', required=True)
    parser.add_argument('--password', help='GCP password', required=True)
    parser.add_argument('--branding-app-name', help='Branding application name', required=True)
    parser.add_argument('--oauth-client-name', help='OAuth client application name', required=True)
    parser.add_argument('--redirect-uris', nargs='+', help='OAuth Redirect URIs', required=True)
    args = parser.parse_args()
    return args

def main() :

    args = read_args()

    with sync_playwright() as pw:
        browser = get_browser(pw)
        page = browser.new_page()

        login(page, args.project_id, args.username, args.password)
        create_branding(page, args.project_id, args.branding_app_name, args.username, args.username)
        client_id, client_secret = create_client(page, args.project_id, args.oauth_client_name, args.redirect_uris)
        browser.close()

    with open("oauth_client_env.sh", "w") as file:
        file.write(f"""
OAUTH_CLIENT_ID={client_id}
OAUTH_CLIENT_SECRET={client_secret}
export OAUTH_CLIENT_ID
export OAUTH_CLIENT_SECRET""")

main()