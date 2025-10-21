#!/usr/bin/env python3
"""
Download files from a specific folder in a GitHub repo using the Contents API.
Saves files under ./raw_files/<owner>-<repo>-<branch>-<path>/
"""
import os
import requests
from urllib.parse import quote_plus
from dotenv import load_dotenv
from tqdm import tqdm

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = os.getenv("REPO_OWNER")
REPO_NAME = os.getenv("REPO_NAME")
REPO_BRANCH = os.getenv("REPO_BRANCH", "main")
TARGET_FOLDER = os.getenv("TARGET_FOLDER", "")  # path inside repo, e.g. src/myproj
OUT_DIR = os.getenv("OUT_DIR", "raw_files")

if not (GITHUB_TOKEN and REPO_OWNER and REPO_NAME and TARGET_FOLDER):
    raise SystemExit("Please set GITHUB_TOKEN, REPO_OWNER, REPO_NAME, and TARGET_FOLDER in .env")

session = requests.Session()
session.headers.update({"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"})

def fetch_folder(owner, repo, path, ref):
    api_url = f"https://api.github.com/repos/{owner}/{repo}/contents/{quote_plus(path)}?ref={ref}"
    r = session.get(api_url)
    r.raise_for_status()
    return r.json()

def download_file(item, out_dir):
    if item.get("type") != "file":
        return
    raw_url = item.get("download_url")
    if not raw_url:
        return
    os.makedirs(out_dir, exist_ok=True)
    filename = os.path.join(out_dir, item["name"])
    # stream download
    with session.get(raw_url, stream=True) as rr:
        rr.raise_for_status()
        with open(filename, "wb") as f:
            for chunk in rr.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)

def walk_and_download(owner, repo, path, ref, out_root):
    items = fetch_folder(owner, repo, path, ref)
    # items could be a file (dict) or list
    if isinstance(items, dict) and items.get("type") == "file":
        # single file
        out_dir = os.path.join(out_root, owner, repo, ref, path)
        download_file(items, out_dir)
        return
    for item in tqdm(items, desc=f"Downloading {path}"):
        if item["type"] == "file":
            out_dir = os.path.join(out_root, owner, repo, ref, path)
            download_file(item, out_dir)
        elif item["type"] == "dir":
            walk_and_download(owner, repo, os.path.join(path, item["name"]), ref, out_root)

if __name__ == "__main__":
    out_root = OUT_DIR
    walk_and_download(REPO_OWNER, REPO_NAME, TARGET_FOLDER, REPO_BRANCH, out_root)
    print("Download complete. Files saved under", out_root)