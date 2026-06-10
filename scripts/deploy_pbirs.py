import os
import sys
import requests
from requests_ntlm import HttpNtlmAuth

PBIRS_HOST = os.environ.get("PBIRS_HOST", "http://DESKTOP-HHC5U09/reports")
PBIRS_USER = os.environ.get("PBIRS_USER", "Admin")
PBIRS_PASS = os.environ.get("PBIRS_PASS", "")

auth = HttpNtlmAuth(PBIRS_USER, PBIRS_PASS)


def list_reports():
    resp = requests.get(f"{PBIRS_HOST}/api/v2.0/PowerBIReports", auth=auth)
    resp.raise_for_status()
    return resp.json()["value"]


def deploy(pbix_path: str):
    name = os.path.splitext(os.path.basename(pbix_path))[0]
    reports = list_reports()
    match = next((r for r in reports if r["Name"] == name), None)

    if not match:
        print(f"'{name}' not found on PBIRS — skip")
        return

    with open(pbix_path, "rb") as f:
        resp = requests.put(
            f"{PBIRS_HOST}/api/v2.0/PowerBIReports('{match['Id']}')/Content",
            headers={"Content-Type": "application/octet-stream"},
            data=f,
            auth=auth,
        )
    resp.raise_for_status()
    print(f"Deployed: {match['Path']}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: deploy_pbirs.py <path/to/file.pbix>")
        sys.exit(1)
    deploy(sys.argv[1])
dummy change
