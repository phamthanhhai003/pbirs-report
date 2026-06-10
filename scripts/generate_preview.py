import sys
import json
import subprocess
import os

PREVIEW_FILE = os.path.join(os.environ.get("TEMP", "/tmp"), "pbirs_preview.html")
MEASURES_JSON = os.path.join(os.environ.get("TEMP", "/tmp"), "pbirs_measures.json")
PREV_JSON = os.path.join(os.environ.get("TEMP", "/tmp"), "pbirs_measures_prev.json")


def git_show_prev_json():
    """Get measure HTML values from previous commit's .dax files (best-effort)."""
    prev = {}
    result = subprocess.run(
        ["git", "show", "HEAD:scripts/.measures_cache.json"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        try:
            prev = json.loads(result.stdout)
        except Exception:
            pass
    return prev


def build_preview(current: dict, previous: dict) -> str:
    changed_keys = [k for k in current if current.get(k) != previous.get(k) and current.get(k)]
    all_keys = changed_keys if changed_keys else [k for k in current if current.get(k) and k != "PageNum__Page Number Value"]

    sections = ""
    for key in all_keys:
        name = key.replace("__", " / ").replace("_", " ")
        after_html = current.get(key, "")
        before_html = previous.get(key, "")
        changed = after_html != before_html

        badge = "<span style='background:#fbbf24;color:#78350f;font-size:10px;padding:2px 8px;border-radius:10px;font-weight:700;margin-left:8px;'>CHANGED</span>" if changed else ""

        if changed and before_html:
            panes = f"""
            <div style='display:flex;gap:0;'>
              <div style='flex:1;border-right:3px solid #e2e8f0;'>
                <div style='background:#fee2e2;color:#991b1b;font-size:11px;font-weight:700;padding:6px 14px;text-transform:uppercase;letter-spacing:1px;'>BEFORE</div>
                <div style='padding:12px;overflow-x:auto;'>{before_html}</div>
              </div>
              <div style='flex:1;'>
                <div style='background:#dcfce7;color:#166534;font-size:11px;font-weight:700;padding:6px 14px;text-transform:uppercase;letter-spacing:1px;'>AFTER</div>
                <div style='padding:12px;overflow-x:auto;'>{after_html}</div>
              </div>
            </div>"""
        else:
            panes = f"""
            <div style='background:#dcfce7;color:#166534;font-size:11px;font-weight:700;padding:6px 14px;text-transform:uppercase;letter-spacing:1px;'>CURRENT</div>
            <div style='padding:12px;overflow-x:auto;'>{after_html}</div>"""

        sections += f"""
        <div style='background:#fff;border-radius:8px;box-shadow:0 1px 4px rgba(0,0,0,.1);margin:16px;overflow:hidden;'>
          <div style='background:#1e293b;color:#f0a500;font-size:12px;font-weight:700;padding:8px 14px;text-transform:uppercase;letter-spacing:1px;display:flex;align-items:center;'>
            {name}{badge}
          </div>
          {panes}
        </div>"""

    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<title>Report Preview</title>
<style>
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; font-family: Segoe UI, sans-serif; background: #f1f5f9; }}
</style>
</head>
<body>
<div style='background:#003366;color:#fff;padding:14px 20px;font-size:15px;font-weight:700;border-bottom:4px solid #f0a500;'>
  PBIRS Report Preview
  {"<span style='background:#fbbf24;color:#78350f;font-size:11px;padding:3px 10px;border-radius:10px;font-weight:700;margin-left:12px;'>Changes detected</span>" if changed_keys else ""}
</div>
{sections}
</body>
</html>"""


if __name__ == "__main__":
    with open(MEASURES_JSON, encoding="utf-8") as f:
        current = json.load(f)

    previous = git_show_prev_json()

    html = build_preview(current, previous)

    with open(PREVIEW_FILE, "w", encoding="utf-8") as f:
        f.write(html)

    # Save current as cache for next diff
    with open(".measures_cache.json", "w", encoding="utf-8") as f:
        json.dump(current, f, ensure_ascii=False, indent=2)

    print(f"Preview saved: {PREVIEW_FILE}")
