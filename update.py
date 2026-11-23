#!/usr/bin/env python3
"""Update pkgs/pcloud/default.nix to the latest pCloud Linux release."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PACKAGE_FILE = ROOT / "pkgs/pcloud" / "default.nix"
UPDATE_FEED_URL = "https://api.pcloud.com/getlastversion?os=ELECTRONV2"
USER_AGENT = "pcloud-nix-update/1.0"


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def latest_release() -> dict:
    data = fetch_json(UPDATE_FEED_URL)
    if not data.get("version") or not data.get("files"):
        raise RuntimeError(f"Unexpected pCloud update feed response: {data}")
    return data


def appimage_file(release: dict) -> dict:
    files = release.get("files", [])
    for file in files:
        url = file.get("url", "")
        if url.endswith("/pCloud.AppImage"):
            return file
    if files:
        return files[0]
    raise RuntimeError("pCloud update feed did not include any files")


def download_file(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        with destination.open("wb") as output:
            shutil.copyfileobj(response, output, length=1024 * 1024)


def file_hashes(path: Path) -> dict[str, str]:
    digests = {
        "sha256": hashlib.sha256(),
        "sha512": hashlib.sha512(),
    }
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            for digest in digests.values():
                digest.update(chunk)
    return {name: digest.hexdigest() for name, digest in digests.items()}


def field_value(text: str, field: str) -> str:
    match = re.search(rf'^\s*{field}\s*=\s*"([^"]+)";', text, re.MULTILINE)
    if not match:
        raise RuntimeError(f"Could not find {field} in {PACKAGE_FILE}")
    return match.group(1)


def replace_field(text: str, field: str, value: str) -> str:
    pattern = re.compile(rf"^\s*{field}\s*=.*$", re.MULTILINE)
    match = pattern.search(text)
    if not match:
        raise RuntimeError(f"Could not find {field} in {PACKAGE_FILE}")

    old_line = match.group(0)
    new_line = re.sub(r'"[^"]*"', f'"{value}"', old_line, count=1)
    return text.replace(old_line, new_line, 1)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Update the pCloud package to the latest Linux release."
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="re-download the AppImage and refresh outputHash even when the "
        "version is unchanged",
    )
    args = parser.parse_args()

    release = latest_release()
    version = release["version"]
    artifact = appimage_file(release)
    url = artifact["url"]

    text = PACKAGE_FILE.read_text()
    current_version = field_value(text, "version")
    current_hash = field_value(text, "outputHash")

    host = urllib.parse.urlparse(url).netloc
    print(f"Latest pCloud Linux release: {version}")
    print(f"Current package: {current_version} ({current_hash[:12]}...)")
    print(f"Artifact: {host} ({artifact.get('size', 'unknown')} bytes)")

    if not args.force and version == current_version:
        print("pCloud is already up to date.")
        return 0

    with tempfile.TemporaryDirectory(prefix="pcloud-update-") as temp_dir:
        appimage = Path(temp_dir) / "pCloud.AppImage"
        print(f"Downloading pCloud.AppImage from {host}...")
        download_file(url, appimage)

        expected_size = artifact.get("size")
        if expected_size is not None and appimage.stat().st_size != expected_size:
            raise RuntimeError(
                f"Downloaded size {appimage.stat().st_size} does not match "
                f"expected size {expected_size}"
            )

        hashes = file_hashes(appimage)

    expected_sha512 = artifact.get("sha512")
    if expected_sha512 and hashes["sha512"] != expected_sha512:
        raise RuntimeError("Downloaded AppImage sha512 does not match update feed")

    new_hash = hashes["sha256"]
    updates = []
    if version != current_version:
        updates.append(("version", version))
    if new_hash != current_hash:
        updates.append(("outputHash", new_hash))

    if not updates:
        print("No package changes needed.")
        return 0

    for field, value in updates:
        text = replace_field(text, field, value)
    PACKAGE_FILE.write_text(text)

    print(f"Updated {PACKAGE_FILE.relative_to(ROOT)}:")
    for field, value in updates:
        print(f"  {field} = {value}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
