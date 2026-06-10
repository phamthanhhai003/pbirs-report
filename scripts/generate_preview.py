import sys
import re
import html


def parse_diff(diff_text: str):
    """Parse git diff into list of (filename, before, after) tuples."""
    changes = []
    current_file = None
    before_lines = []
    after_lines = []

    for line in diff_text.splitlines():
        if line.startswith("diff --git"):
            if current_file:
                changes.append((current_file, "\n".join(before_lines), "\n".join(after_lines)))
            m = re.search(r"b/(.+)$", line)
            current_file = m.group(1) if m else line
            before_lines = []
            after_lines = []
        elif line.startswith("---") or line.startswith("+++") or line.startswith("@@"):
            continue
        elif line.startswith("-"):
            before_lines.append(line[1:])
        elif line.startswith("+"):
            after_lines.append(line[1:])
        else:
            before_lines.append(line[1:] if line.startswith(" ") else line)
            after_lines.append(line[1:] if line.startswith(" ") else line)

    if current_file:
        changes.append((current_file, "\n".join(before_lines), "\n".join(after_lines)))

    return changes


def render_html(changes):
    rows = ""
    for filename, before, after in changes:
        rows += f"""
        <tr class="filename-row"><td colspan="2">{html.escape(filename)}</td></tr>
        <tr>
            <td class="before"><pre>{html.escape(before)}</pre></td>
            <td class="after"><pre>{html.escape(after)}</pre></td>
        </tr>"""

    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>DAX Preview</title>
<style>
  body {{ font-family: monospace; background: #1e1e1e; color: #d4d4d4; margin: 0; }}
  h1 {{ padding: 16px; background: #252526; margin: 0; font-size: 14px; }}
  table {{ width: 100%; border-collapse: collapse; }}
  th {{ background: #252526; padding: 8px; text-align: left; font-size: 12px; color: #9d9d9d; }}
  td {{ vertical-align: top; padding: 8px; border-bottom: 1px solid #333; font-size: 12px; }}
  td.before {{ background: #3a1a1a; width: 50%; }}
  td.after  {{ background: #1a3a1a; width: 50%; }}
  tr.filename-row td {{ background: #2d2d2d; color: #ce9178; padding: 6px 8px; font-weight: bold; }}
  pre {{ margin: 0; white-space: pre-wrap; word-break: break-word; }}
</style>
</head>
<body>
<h1>DAX Changes Preview</h1>
<table>
  <tr><th>BEFORE</th><th>AFTER</th></tr>
  {rows}
</table>
</body>
</html>"""


if __name__ == "__main__":
    diff_file = sys.argv[1] if len(sys.argv) > 1 else "/dev/stdin"
    with open(diff_file, "r", encoding="utf-8") as f:
        diff_text = f.read()

    changes = parse_diff(diff_text)
    if not changes:
        print("<html><body><p>No DAX changes detected.</p></body></html>")
    else:
        print(render_html(changes))
