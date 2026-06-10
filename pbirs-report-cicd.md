# PBIRS CI/CD Plan

## Mục tiêu

Dev sửa báo cáo Power BI → xem preview thay đổi → commit → tự động deploy lên Power BI Report Server (PBIRS). Không cần thao tác thủ công trên server.

---

## Luồng đầy đủ

```
1. Dev sửa measure trong PBI Desktop RS → Save .pbix
        ↓
2. git commit  (file vẫn đang mở trong PBI Desktop RS)
        ↓
3. Pre-commit hook tự chạy:
   a. extract_dax.ps1   — connect AMO → msmdsrv.exe đang chạy (port động)
                        → extract tất cả measures → source/measures/**/*.dax
   b. eval_measures.ps1 — chạy từng measure qua AdomdClient (DAX query)
                        → lưu kết quả HTML vào %TEMP%\pbirs_measures.json
   c. generate_preview.py — so sánh với HEAD:.measures_cache.json
                          → chỉ render measures đã thay đổi
                          → HTML before/after side-by-side
   d. Mở browser → user xem trực tiếp kết quả render (không phải diff code)
   e. Hỏi xác nhận: tiếp tục hay hủy? (y/n)
        ↓ y
4. Commit hoàn tất — .dax files + .measures_cache.json + CreditReport.pbix
        ↓
5. git push → Jenkins pipeline:
   - upload_pbirs.ps1 → Write-RsRestCatalogItem → PBIRS cập nhật
        ↓
6. Report trên PBIRS được cập nhật tự động
```

> **Lưu ý:** File phải đang mở trong PBI Desktop RS khi commit (msmdsrv.exe phải đang chạy).
> pbi-tools bị loại bỏ — DataModel là binary ABF (XPress9 compressed), không compatible.

---

## Environment

| | |
|--|--|
| PBIRS Version | 15.0.1121.109 (May 2026) |
| PBIRS Host | `192.168.100.98` |
| REST API base | `http://192.168.100.98/reports/api/v2.0` |
| Auth | **NTLM (Windows Auth)** — confirmed via `WWW-Authenticate: NTLM` |
| PBI Desktop RS | `C:\Program Files\Microsoft Power BI Desktop RS\bin` |
| Tabular Editor 2 | `C:\Program Files (x86)\Tabular Editor` |
| msmdsrv port | Động — detect qua `netstat -ano` theo PID |
| Credentials | `Admin` / env var `PBIRS_PASS` (mặc định `20032003` local) |
| WSL2 note | `localhost` không reach từ WSL2 — dùng `DESKTOP-HHC5U09` hoặc Windows host IP |

---

## Repo Structure

```
pbirs-report/
├── source/
│   └── measures/
│       ├── final_provision_report/
│       │   ├── Provision_HTML.dax
│       │   └── ...
│       ├── final_repayment_report/
│       │   └── Repayment_HTML.dax
│       └── ...                         ← git tracked, readable trong VS Code
├── scripts/
│   ├── extract_dax.ps1                 ← AMO connect → extract measures ra .dax files
│   ├── eval_measures.ps1               ← AdomdClient → chạy DAX → lưu HTML JSON
│   ├── generate_preview.py             ← so sánh cache → render HTML before/after
│   ├── upload_pbirs.ps1                ← ReportingServicesTools → deploy .pbix lên PBIRS
│   ├── deploy_pbirs.py                 ← NTLM deploy (backup, dùng khi PS không available)
│   ├── patch_measure.ps1               ← chỉnh sửa measure trực tiếp qua AMO (test)
│   └── restore_measure.ps1             ← restore measure từ .dax file qua AMO (test)
├── hooks/
│   └── pre-commit                      ← source of truth, copy vào .git/hooks/
├── .git/hooks/
│   └── pre-commit                      ← active hook
├── .vscode/
│   └── tasks.json                      ← auto git pull khi mở VS Code
├── Jenkinsfile
├── CreditReport.pbix
├── .measures_cache.json                ← auto-generated, track HTML output của measures
├── requirements.txt
└── .gitignore
```

---

## Các file đã build

### 1. `hooks/pre-commit`

```bash
#!/bin/bash
PYTHON="python"
command -v "$PYTHON" >/dev/null 2>&1 || PYTHON="python3"
command -v "$PYTHON" >/dev/null 2>&1 || PYTHON="python.exe"

# Step 1: Extract DAX measures ra source/
powershell.exe -ExecutionPolicy Bypass -File "scripts/extract_dax.ps1" -OutputDir "./source"

# Step 2: Chạy từng measure → lưu HTML output vào %TEMP%\pbirs_measures.json
WIN_TEMP="$(powershell.exe -Command 'Write-Host $env:TEMP' 2>/dev/null | tr -d '\r')"
WSL_TEMP="$(wslpath "$WIN_TEMP" 2>/dev/null || echo "/tmp")"
powershell.exe -ExecutionPolicy Bypass -File "scripts/eval_measures.ps1"

# Step 3: So sánh với HEAD cache → tạo HTML preview chỉ measures đã đổi
"$PYTHON" scripts/generate_preview.py "$WSL_TEMP/pbirs_measures.json" "$WSL_TEMP/pbirs_preview.html"

# Step 4: Mở browser (WSL2 aware)
PREVIEW_FILE="$WIN_TEMP\\pbirs_preview.html"
case "$(uname -s)" in
    Darwin*) open "$PREVIEW_FILE" ;;
    CYGWIN*|MINGW*|MSYS*) start "$PREVIEW_FILE" ;;
    Linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            explorer.exe "$(wslpath -w "$WSL_TEMP/pbirs_preview.html")"
        else xdg-open "$WSL_TEMP/pbirs_preview.html"; fi ;;
esac

# Step 5: Xác nhận
if [ -t 0 ]; then
    read -p "Tiep tuc commit? (y/n): " confirm
    [ "$confirm" != "y" ] && echo "Commit huy" && exit 1
else
    echo "Khong co terminal — tu dong tiep tuc"
fi

git add source/ .measures_cache.json 2>/dev/null
git add source/
```

---

### 2. `scripts/extract_dax.ps1`

Connect AMO vào msmdsrv.exe đang chạy → extract tất cả measures ra `.dax` files.

- Load DLLs từ PBI Desktop RS bin + Tabular Editor 2
- Tìm port msmdsrv qua `netstat -ano` theo PID
- Với mỗi measure: tạo file `source/measures/<table>/<measure>.dax`
- Format file: `MEASURE 'table'[name] =\n<expression>`

---

### 3. `scripts/eval_measures.ps1`

Chạy từng measure qua AdomdClient → lưu HTML output vào JSON.

```powershell
# Load DLLs
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices.AdomdClient")

# Tìm port msmdsrv động
$port = (netstat -ano | Select-String $pid_ | Select-String "LISTENING" | ...)

# AMO: lấy danh sách measures
$server.Connect("localhost:$port")
# ...

# AdomdClient: chạy từng measure
$conn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$port")
$cmd.CommandText = "EVALUATE ROW(`"R`", 'table'[measure])"
# result lưu vào $results["table__measure"] = HTML string

$results | ConvertTo-Json | Set-Content $OutputJson -Encoding UTF8
```

Output: `%TEMP%\pbirs_measures.json` — format `{ "table__measure": "<html>" }`

---

### 4. `scripts/generate_preview.py`

So sánh output hiện tại với `HEAD:.measures_cache.json` → render chỉ measures đã thay đổi.

- `git show HEAD:.measures_cache.json` → previous state
- Tìm `changed_keys = [k for k in current if current[k] != previous.get(k)]`
- Mỗi measure thay đổi: render BEFORE (header đỏ) | AFTER (header xanh) side-by-side
- HTML output là rendered HTML table — không phải code diff
- Lưu `.measures_cache.json` mới để commit cùng

---

### 5. `scripts/upload_pbirs.ps1`

Deploy `.pbix` lên PBIRS dùng ReportingServicesTools module.

```powershell
Import-Module ReportingServicesTools
$cred = New-Object System.Management.Automation.PSCredential("Admin",
    (ConvertTo-SecureString $env:PBIRS_PASS -AsPlainText -Force))
# Xóa report cũ (nếu có) rồi upload lại
Remove-RsRestCatalogItem -ReportServerUri "http://DESKTOP-HHC5U09/reports" -RsItem "/Credit Report" ...
Write-RsRestCatalogItem -ReportServerUri "http://DESKTOP-HHC5U09/reports" -Path "CreditReport.pbix" ...
```

---

### 6. `scripts/patch_measure.ps1` / `restore_measure.ps1`

Utility dùng khi test — chỉnh sửa hoặc restore measure trực tiếp qua AMO mà không cần reopen PBI Desktop RS.

- `patch_measure.ps1 -Action remove` — xóa block HTML khỏi expression
- `restore_measure.ps1 -DaxFile <path>` — restore từ file `.dax` (`Get-Content -Raw`)

---

### 7. `Jenkinsfile`

```groovy
pipeline {
    agent { label 'windows' }
    environment {
        PBIRS_HOST = 'http://DESKTOP-HHC5U09/reports'
        PBIRS_USER = credentials('pbirs-user')
        PBIRS_PASS = credentials('pbirs-pass')
    }
    stages {
        stage('Deploy to PBIRS') {
            steps {
                bat 'powershell -ExecutionPolicy Bypass -File scripts/upload_pbirs.ps1'
            }
        }
    }
}
```

---

### 8. `.measures_cache.json`

Auto-generated bởi `generate_preview.py` mỗi commit.

```json
{
  "final_provision_report__Provision_HTML": "<table>...</table>",
  "final_repayment_report__Repayment_HTML": "<table>...</table>",
  ...
}
```

Commit cùng với `.dax` files. Lần commit sau dùng `git show HEAD:.measures_cache.json` để so sánh.

---

## Prerequisites

| Tool | Version/Path | Dùng để |
|------|-------------|---------|
| PBI Desktop RS | `C:\Program Files\Microsoft Power BI Desktop RS` | Cần mở file khi commit |
| Tabular Editor 2 | `C:\Program Files (x86)\Tabular Editor` | AMO DLLs cho extract + patch |
| ReportingServicesTools | PS module, installed globally | Upload .pbix lên PBIRS |
| Python 3 | trong PATH | generate_preview.py |
| Git + WSL2 | — | Pre-commit hook chạy trong WSL2 |

---

## Checklist

- [x] PBIRS service UP tại `DESKTOP-HHC5U09`
- [x] NTLM auth xác nhận
- [x] Upload .pbix hoạt động (ReportingServicesTools)
- [x] extract_dax.ps1 — extract measures qua AMO
- [x] eval_measures.ps1 — chạy measures qua AdomdClient
- [x] generate_preview.py — before/after HTML preview, chỉ measures đã đổi
- [x] Pre-commit hook — end-to-end flow hoạt động
- [x] .measures_cache.json — change detection giữa các commit
- [ ] Jenkins Windows agent setup
- [ ] Jenkins pipeline test (push → auto deploy)
- [ ] Credentials dùng env var (không hardcode) trong upload_pbirs.ps1
