import sys
import json
import subprocess
import os
import difflib
import re

MEASURES_JSON = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "pbirs_measures.json")
PREVIEW_FILE  = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.environ.get("TEMP", "/tmp"), "pbirs_preview.html")


def extract_diff_chunks(before_html: str, after_html: str, context: int = 300):
    """Return (before_snippet, after_snippet) showing only the changed region."""
    # Find common prefix/suffix char positions
    min_len = min(len(before_html), len(after_html))
    prefix = 0
    while prefix < min_len and before_html[prefix] == after_html[prefix]:
        prefix += 1

    suffix = 0
    while suffix < min_len - prefix and before_html[-(suffix+1)] == after_html[-(suffix+1)]:
        suffix += 1

    # Expand to nearest tag boundary for cleaner rendering
    def snap_to_tag(s, pos, direction="left"):
        if direction == "left":
            i = s.rfind("<", 0, pos)
            return i if i >= 0 else 0
        else:
            i = s.find(">", pos)
            return i + 1 if i >= 0 else len(s)

    b_start = max(0, snap_to_tag(before_html, prefix - context, "left"))
    b_end   = min(len(before_html), snap_to_tag(before_html, len(before_html) - suffix + context, "right"))
    a_start = max(0, snap_to_tag(after_html,  prefix - context, "left"))
    a_end   = min(len(after_html),  snap_to_tag(after_html,  len(after_html)  - suffix + context, "right"))

    ellipsis = "<div style='color:#9ca3af;font-size:10px;padding:4px 8px;'>...</div>"
    before_chunk = (ellipsis if b_start > 0 else "") + before_html[b_start:b_end] + (ellipsis if b_end < len(before_html) else "")
    after_chunk  = (ellipsis if a_start > 0 else "") + after_html[a_start:a_end]  + (ellipsis if a_end  < len(after_html)  else "")

    return before_chunk, after_chunk


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

    if not changed_keys:
        return "<html><body style='font-family:Segoe UI;padding:40px;background:#f1f5f9;'><div style='background:#fff;border-radius:8px;padding:24px;text-align:center;color:#6b7280;'>No changes detected.</div></body></html>"

    sections = ""
    for key in changed_keys:
        name = key.replace("__", " / ").replace("_", " ")
        after_html = current.get(key, "")
        before_html = previous.get(key, "")
        changed = after_html != before_html

        badge = "<span style='background:#fbbf24;color:#78350f;font-size:10px;padding:2px 8px;border-radius:10px;font-weight:700;margin-left:8px;'>CHANGED</span>" if changed else ""

        if changed and before_html:
            before_chunk, after_chunk = extract_diff_chunks(before_html, after_html)
            panes = f"""
            <div style='display:flex;gap:0;'>
              <div style='flex:1;border-right:3px solid #e2e8f0;min-width:0;'>
                <div style='background:#fee2e2;color:#991b1b;font-size:11px;font-weight:700;padding:6px 14px;text-transform:uppercase;letter-spacing:1px;'>BEFORE</div>
                <div style='padding:12px;overflow-x:auto;'>{before_chunk}</div>
              </div>
              <div style='flex:1;min-width:0;'>
                <div style='background:#dcfce7;color:#166534;font-size:11px;font-weight:700;padding:6px 14px;text-transform:uppercase;letter-spacing:1px;'>AFTER</div>
                <div style='padding:12px;overflow-x:auto;'>{after_chunk}</div>
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
    with open(MEASURES_JSON, encoding="utf-8-sig") as f:
        current = json.load(f)

    previous = git_show_prev_json()

    html = build_preview(current, previous)

    with open(PREVIEW_FILE, "w", encoding="utf-8") as f:
        f.write(html)

    # Save current as cache for next diff
    with open(".measures_cache.json", "w", encoding="utf-8") as f:
        json.dump(current, f, ensure_ascii=False, indent=2)

    print(f"Preview saved: {PREVIEW_FILE}")
