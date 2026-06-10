import sys
import json
import subprocess
import os

MEASURES_JSON = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "pbirs_measures.json")
PREVIEW_FILE  = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.environ.get("TEMP", "/tmp"), "pbirs_preview.html")


def git_show_prev_json():
    result = subprocess.run(
        ["git", "show", "HEAD:.measures_cache.json"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        try:
            return json.loads(result.stdout)
        except Exception:
            pass
    return {}


def build_preview(current: dict, previous: dict) -> str:
    changed_keys = [k for k in current if current.get(k) != previous.get(k) and current.get(k)]

    if not changed_keys:
        return """<!DOCTYPE html><html><body style='font-family:Segoe UI;padding:40px;background:#f1f5f9;'>
        <p style='color:#6b7280;text-align:center;'>No changes detected.</p>
        </body></html>"""

    sections = ""
    for key in changed_keys:
        after_html  = current.get(key, "")
        before_html = previous.get(key, "")
        name = key.split("__")[-1].replace("_", " ")

        sections += f"""
        <div style='margin:0 0 32px 0;'>
          <div style='background:#1e293b;color:#f0a500;font-weight:700;font-size:12px;
                      padding:8px 16px;text-transform:uppercase;letter-spacing:1px;'>
            {name}
          </div>
          <div style='display:flex;'>
            <div style='flex:1;min-width:0;border-right:3px solid #dc2626;'>
              <div style='background:#fee2e2;color:#991b1b;font-weight:700;font-size:11px;
                          padding:5px 12px;text-transform:uppercase;'>BEFORE</div>
              <div style='overflow-x:auto;'>{before_html}</div>
            </div>
            <div style='flex:1;min-width:0;'>
              <div style='background:#dcfce7;color:#166534;font-weight:700;font-size:11px;
                          padding:5px 12px;text-transform:uppercase;'>AFTER</div>
              <div style='overflow-x:auto;'>{after_html}</div>
            </div>
          </div>
        </div>"""

    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<title>Preview</title>
<style>* {{ box-sizing:border-box; }} body {{ margin:0; background:#f1f5f9; }}</style>
</head>
<body>{sections}</body>
</html>"""


if __name__ == "__main__":
    with open(MEASURES_JSON, encoding="utf-8-sig") as f:
        current = json.load(f)

    previous = git_show_prev_json()
    html = build_preview(current, previous)

    with open(PREVIEW_FILE, "w", encoding="utf-8") as f:
        f.write(html)

    with open(".measures_cache.json", "w", encoding="utf-8") as f:
        json.dump(current, f, ensure_ascii=False, indent=2)

    print(f"Preview saved: {PREVIEW_FILE}")
