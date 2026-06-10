# PBIRS CI/CD Plan

## Mục tiêu

Dev hoặc AI sửa measure Power BI → xem preview HTML before/after → commit → tự động deploy lên PBIRS. Không thao tác thủ công trên server.

---

## Luồng đầy đủ

```
[AI-driven path]
1. User prompt: "gỡ Total Write-Off khỏi Extra Accountable"
        ↓
2. AI chạy patch_measure.ps1 -CardLabel "Total Write-Off"
   → Script scan tất cả measures, tìm card, xóa block HTML
        ↓
3. PostToolUse hook tự kick (không cần AI gọi thêm):
   - eval_measures.ps1  → chạy DAX → lưu HTML output
   - generate_preview.py → so sánh HEAD cache → render BEFORE/AFTER
   - Mở browser tự động
        ↓
4. AI hỏi: "Preview ổn chưa? Muốn commit không?"
        ↓ y
5. git commit → pre-commit hook:
   - extract_dax.ps1    → detect port động → AMO → extract .dax files
   - Nếu DAX thay đổi: eval + preview + hỏi y/n
   - Nếu không đổi: skip eval, commit ngay
        ↓
6. AI hỏi: "Muốn push không?"
        ↓ y
7. git push → Jenkins deploy → PBIRS 192.168.100.98 cập nhật

[Manual path — khi AI không sửa được DAX]
1. User mở PBI Desktop RS → sửa DAX trực tiếp → Ctrl+S
2. git commit → pre-commit hook (như bước 5 trên)
3. git push → Jenkins deploy
```

> **Bắt buộc:** File .pbix phải đang mở trong PBI Desktop RS khi chạy bất kỳ script nào.

---

## Environment

| | |
|--|--|
| PBIRS Host | `http://192.168.100.98/reports` |
| Auth | NTLM — `$env:PBIRS_PASS` |
| PBI Desktop RS | `C:\Program Files\Microsoft Power BI Desktop RS` |
| Tabular Editor 2 | `C:\Program Files (x86)\Tabular Editor` |
| msmdsrv port | Tự detect qua `netstat -ano` theo PID |
| Config máy | `scripts/config.ps1` (gitignored) — copy từ `config.example.ps1` |

---

## Repo Structure

```
pbirs-report/
├── source/
│   └── measures/
│       ├── final_provision_report/
│       │   ├── Provision_HTML.dax
│       │   └── Provision_HTML_v2.dax
│       ├── final_repayment_report/
│       │   └── Repayment_HTML.dax
│       ├── final_extra_accountable_report/
│       │   └── ExtraAccountable_HTML.dax
│       └── ...
├── scripts/
│   ├── config.ps1              ← gitignored, mỗi máy tự tạo
│   ├── config.example.ps1      ← template
│   ├── extract_dax.ps1         ← AMO → extract measures → .dax files
│   ├── eval_measures.ps1       ← AdomdClient → chạy DAX → HTML JSON
│   ├── generate_preview.py     ← so sánh cache → HTML before/after
│   ├── upload_pbirs.ps1        ← deploy .pbix lên PBIRS
│   ├── patch_measure.ps1       ← xóa card HTML khỏi bất kỳ measure nào
│   └── restore_measure.ps1     ← restore measure từ .dax file
├── hooks/
│   └── pre-commit              ← source of truth
├── .git/hooks/pre-commit       ← active hook (copy từ hooks/)
├── .claude/
│   └── settings.json           ← PostToolUse hook config
├── CLAUDE.md                   ← AI instructions
├── Jenkinsfile
├── .measures_cache.json        ← auto-generated, baseline so sánh
└── .gitignore
```

---

## Scripts

### `scripts/patch_measure.ps1`

Xóa card HTML khỏi measure. **Scan tất cả measures** — không hardcode report.

```powershell
# Xóa card bất kỳ, script tự tìm measure chứa nó
patch_measure.ps1 -CardLabel "Total Write-Off"

# Giới hạn table nếu cần
patch_measure.ps1 -CardLabel "Total Loans" -Table "final_provision_report"
```

Cards có thể xóa (bất kỳ report nào có cấu trúc `<div>Label</div><div>Value</div>`):
- Provision: Total Loans, Total Outstanding, Total Commitment, Total Provision, Outstanding Delta
- Extra Accountable: Total Accounts, Balance P+I+Pen, Total Write-Off, Principal, Princ. Interest, Delta

### `scripts/restore_measure.ps1`

Restore measure từ file .dax. Luôn truyền đủ 3 params.

```powershell
restore_measure.ps1 -DaxFile "source/measures/<table>/<measure>.dax" -Table "<table>" -Measure "<measure>"
```

### `scripts/extract_dax.ps1`

Connect AMO → detect port msmdsrv → extract tất cả measures ra `source/measures/`.

### `scripts/eval_measures.ps1`

AdomdClient → chạy từng measure → lưu HTML output vào `%TEMP%\pbirs_measures.json`.

### `scripts/generate_preview.py`

So sánh output hiện tại với `HEAD:.measures_cache.json`. Chỉ render measures đã thay đổi. Output: HTML BEFORE | AFTER side-by-side. Cập nhật `.measures_cache.json`.

### `scripts/upload_pbirs.ps1`

Auto-detect .pbix đang mở qua window title / cmdline. Delete + re-upload lên PBIRS.

### `Jenkinsfile`

```groovy
pipeline {
    agent { label 'windows' }
    environment {
        PBIRS_HOST = 'http://192.168.100.98/reports'
        PBIRS_USER = credentials('pbirs-user')
        PBIRS_PASS = credentials('pbirs-pass')
    }
    stages {
        stage('Deploy to PBIRS') {
            steps { bat 'powershell -ExecutionPolicy Bypass -File scripts/upload_pbirs.ps1' }
        }
    }
}
```

---

## Hooks

### Pre-commit (`hooks/pre-commit`)

```
git commit
  → extract_dax.ps1 (luôn chạy — cập nhật .dax files)
  → git diff source/measures/
      → không thay đổi: skip eval, commit ngay
      → có thay đổi: eval_measures.ps1 → generate_preview.py → mở browser → y/n
```

### PostToolUse (`.claude/settings.json`)

Tự động fire sau khi AI chạy `patch_measure.ps1` hoặc `restore_measure.ps1`:
```
eval_measures.ps1 → generate_preview.py → mở browser
```
AI không cần tự gọi eval/preview sau patch/restore.

---

## Cache & baseline

`.measures_cache.json` commit cùng mỗi lần. `git show HEAD:.measures_cache.json` = "before". Nếu preview hiện "No changes" → cache baseline sai. Fix: restore về state đúng → eval → commit cache → rồi mới sửa.

---

## Checklist

- [x] PBIRS UP tại `192.168.100.98`
- [x] NTLM auth xác nhận
- [x] upload_pbirs.ps1 hoạt động
- [x] extract_dax.ps1 — AMO dynamic port
- [x] eval_measures.ps1 — AdomdClient
- [x] generate_preview.py — before/after chỉ measures đã đổi
- [x] Pre-commit hook — skip eval khi không có DAX thay đổi
- [x] patch_measure.ps1 — generic, scan all measures by CardLabel
- [x] restore_measure.ps1 — strip MEASURE header, generic params
- [x] PostToolUse hook — auto preview sau patch/restore
- [x] Config tập trung — config.ps1 gitignored
- [x] Auto-detect .pbix từ window title
- [x] CLAUDE.md — AI instructions + action rules
- [ ] Jenkins Windows agent setup
- [ ] Jenkins pipeline test end-to-end
