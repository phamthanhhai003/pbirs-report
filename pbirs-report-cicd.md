# PBIRS CI/CD Plan

## Mục tiêu

Dev sửa báo cáo Power BI → xem preview thay đổi → commit → tự động deploy lên Power BI Report Server (PBIRS). Không cần thao tác thủ công trên server.

---

## Luồng đầy đủ

```
1. Dev sửa measure trong PBI Desktop RS → Save .pbix
        ↓
2. git commit  (file vẫn mở trong PBI Desktop RS)
        ↓
3. Pre-commit hook tự chạy:
   - Connect AMO → PBI Desktop RS đang chạy (port động)
   - Extract tất cả measures → source/measures/**/*.dax
   - So sánh với HEAD → generate HTML preview before/after
   - Mở browser → hiện diff
   - Hỏi: tiếp tục hay hủy? (y/n)
        ↓ y
4. Commit hoàn tất — .dax files + CreditReport.pbix vào git
        ↓
5. git push → Jenkins pipeline chạy:
   - Upload CreditReport.pbix lên PBIRS (ReportingServicesTools)
        ↓
6. Report trên PBIRS được cập nhật tự động
```

> **Lưu ý:** File phải đang mở trong PBI Desktop RS khi commit.
> pbi-tools bị loại bỏ — DataModel là binary ABF, không compatible.

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
│       └── ...                        ← git track, readable trong VS Code
├── scripts/
│   ├── generate_preview.py            ← tạo HTML diff before/after
│   ├── deploy_pbirs.py                ← upload .pbix lên PBIRS (NTLM)
│   ├── extract_dax.ps1                ← connect AMO → extract measures
│   └── upload_pbirs.ps1               ← upload .pbix qua ReportingServicesTools
├── hooks/
│   └── pre-commit                     ← source of truth, copy vào .git/hooks/
├── .git/hooks/
│   └── pre-commit                     ← active hook
├── .vscode/
│   └── tasks.json                     ← auto git pull khi mở VS Code
├── Jenkinsfile                        ← upload .pbix lên PBIRS
├── CreditReport.pbix                  ← tracked trong git
├── requirements.txt
└── .gitignore
```

---

## Các file đã build

### 1. `.git/hooks/pre-commit`

```bash
#!/bin/bash

# Extract DAX từ PBI Desktop RS đang chạy (file phải đang mở)
powershell.exe -ExecutionPolicy Bypass -File "scripts/extract_dax.ps1" -OutputDir "$SOURCE_DIR"

# Generate HTML preview từ DAX diff
git diff credit-report/Model/ > /tmp/changes.diff
python scripts/generate_preview.py /tmp/changes.diff > /tmp/preview.html

# Mở browser cho user xem
xdg-open /tmp/preview.html   # Linux
# start /tmp/preview.html    # Windows

# Hỏi user
read -p "Tiếp tục commit? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Commit hủy"
    exit 1
fi

git add credit-report/
```

---

### 2. `scripts/generate_preview.py`

Đọc git diff của `.dax` files → render HTML bảng so sánh before/after → user thấy chính xác công thức thay đổi gì.

---

### 3. `scripts/deploy_pbirs.py`

```python
import requests
from requests_ntlm import HttpNtlmAuth

PBIRS_HOST = "http://172.25.240.1/reports"  # Windows host IP từ WSL2
auth = HttpNtlmAuth("DOMAIN\\username", "password")  # thay DOMAIN\\username + password

def deploy(local_name: str, pbix_path: str):
    # Tìm report trùng tên trên PBIRS
    items = requests.get(
        f"{PBIRS_HOST}/api/v2.0/PowerBIReports",
        auth=auth
    ).json()["value"]

    match = next((i for i in items if i["Name"] == local_name), None)

    if not match:
        print(f"'{local_name}' không tồn tại trên server — skip")
        return

    # Ghi đè qua endpoint đúng cho .pbix
    with open(pbix_path, "rb") as f:
        requests.put(
            f"{PBIRS_HOST}/api/v2.0/PowerBIReports('{match['Id']}')/Content",
            headers={"Content-Type": "application/octet-stream"},
            data=f,
            auth=auth
        )
    print(f"Deployed: {match['Path']}")
```

---

### 4. `.vscode/tasks.json`

Tự chạy `git pull` mỗi khi mở repo bằng VS Code:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Auto Pull",
      "type": "shell",
      "command": "git pull",
      "runOptions": {
        "runOn": "folderOpen"
      },
      "presentation": {
        "reveal": "silent",
        "panel": "shared"
      }
    }
  ]
}
```

> Lần đầu mở VS Code sẽ hỏi "Allow automatic tasks?" → bấm **Allow**.

---

### 5. `Jenkinsfile` (deploy stage)

```groovy
// Không dùng pbi-tools — upload .pbix trực tiếp bằng ReportingServicesTools
stage('Deploy to PBIRS') {
    steps {
        bat 'powershell -ExecutionPolicy Bypass -File scripts/upload_pbirs.ps1'
    }
}
```

---

## Environment

| | |
|--|--|
| PBIRS Version | 15.0.1121.109 (May 2026) |
| PBIRS Service | `PowerBIReportServer` (local) |
| REST API base | `http://172.25.240.1/reports/api/v2.0` |
| Auth | **NTLM (Windows Auth)** — confirmed via `WWW-Authenticate: NTLM` header |
| WSL2 note | `localhost` không reach được từ WSL2 — dùng Windows host IP `172.25.240.1` |

---

## Cần xác nhận trước khi build

- [x] Start PBIRS service, truy cập web portal xác nhận hoạt động — UP tại `172.25.240.1` / `DESKTOP-HHC5U09`
- [x] Xác nhận auth method — **NTLM**
- [ ] Xác nhận `pbi-tools` compatible với file `.pbix` của Credit Report
- [ ] Quyết định folder map: tên file → folder trên PBIRS

---

## Tasks triển khai

### Task 1 — Test pbi-tools extract + compile

```bash
# Bước 1: Cài pbi-tools
winget install pbi-tools
# hoặc
choco install pbi-tools

# Bước 2: Extract file thực
cd credit-report/
pbi-tools extract CreditReport.pbix -extractFolder ./source

# Bước 3: Compile lại
pbi-tools compile ./source -outPath CreditReport_test.pbix -overwrite

# Bước 4: Mở cả 2 file trong PBI Desktop, so sánh
# → measure, layout, data source còn nguyên không
```

---

### Task 2 — Jenkins Windows agent

Kiểm tra agent hiện có: **Jenkins UI → Manage Jenkins → Nodes** → xem node nào có label `windows`

**Nếu có agent Windows** — đổi Jenkinsfile:

```groovy
agent { label 'windows' }

stage('Deploy to PBIRS') {
    steps {
        bat 'pbi-tools compile ./source -outPath CreditReport.pbix -overwrite'
        bat 'python scripts/deploy_pbirs.py'
    }
}
```

**Nếu chưa có agent Windows:**

| Option | Cách làm |
|--------|----------|
| Dùng máy local làm agent | Cài Jenkins agent trên máy Windows, connect về Jenkins master |
| Docker Windows container | Chỉ work nếu Jenkins chạy trên Windows host |

> Thực tế nhất: cài Jenkins agent trên máy Windows local vì PBIRS đang chạy ở đó.

---

### Task 3 — Fix pre-commit hook cho Windows

```bash
#!/bin/bash

# Extract .pbix → text files
pbi-tools extract CreditReport.pbix -extractFolder ./source

# Generate HTML preview
git diff source/Model/ > /tmp/changes.diff
python scripts/generate_preview.py /tmp/changes.diff > /tmp/preview.html

# Mở browser — detect OS
case "$(uname -s)" in
    Linux*)              xdg-open /tmp/preview.html ;;
    Darwin*)             open /tmp/preview.html ;;
    CYGWIN*|MINGW*|MSYS*) explorer.exe "$(wslpath -w /tmp/preview.html 2>/dev/null || echo /tmp/preview.html)" ;;
esac

# read -p không work trong VS Code terminal → fallback
if [ -t 0 ]; then
    read -p "Tiếp tục commit? (y/n): " confirm
    [ "$confirm" != "y" ] && echo "Commit hủy" && exit 1
else
    echo "Không có terminal — tự động tiếp tục"
fi

git add source/
```

---

### Task 4 — Credentials PBIRS

Kiểm tra auth type: mở `http://localhost/reports`
- Windows popup = Windows Auth
- Form login = Basic Auth

**Windows Auth** (dùng credentials máy hiện tại — không cần hardcode):

```python
from requests_negotiate_sspi import HttpNegotiateAuth
auth = HttpNegotiateAuth()
```

```bash
pip install requests-negotiate-sspi
```

**Basic Auth:**

```python
import os
auth = (os.environ["PBIRS_USER"], os.environ["PBIRS_PASS"])
```

```groovy
// Lưu trong Jenkins credentials store, inject qua env:
environment {
    PBIRS_USER = credentials('pbirs-user')
    PBIRS_PASS = credentials('pbirs-pass')
}
```

---

### Task 5 — Repo structure

**Option A — 1 repo tất cả report (khuyến nghị):**

```
powerbi-reports/
├── CreditReport/
│   └── source/Model/tables/.../measures/
├── AccountingReport/
│   └── source/
├── scripts/
│   ├── deploy_pbirs.py        ← dùng chung
│   └── generate_preview.py   ← dùng chung
├── .vscode/tasks.json
└── Jenkinsfile
```

CI/CD scan tất cả subfolder, deploy report nào có thay đổi.

**Option B — mỗi report 1 repo:** độc lập hoàn toàn, pipeline riêng từng repo.

> Nên chọn A — scripts dùng chung, 1 Jenkins pipeline, dễ maintain khi số report tăng.

---

## Tools cần cài

```bash
# pbi-tools (Windows)
winget install pbi-tools
# hoặc download từ https://pbi.tools

# Python — auth support
pip install requests-ntlm
pip install requests-negotiate-sspi  # nếu dùng Windows Auth không cần hardcode credentials
```
