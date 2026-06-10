# PBIRS Report — AI Context

Repo này chứa source DAX + CI/CD pipeline cho Power BI Report Server (PBIRS).
Khi user yêu cầu sửa report, chạy đúng luồng dưới đây.

---

## Luồng chuẩn khi user yêu cầu thay đổi

```
1. Dùng patch_measure.ps1 hoặc restore_measure.ps1 để sửa measure trong live model
   → PostToolUse hook TỰ ĐỘNG chạy eval + mở preview ngay sau khi AI gọi script
   → AI KHÔNG cần tự chạy eval hay preview — hook đã lo
2. User xem preview trong browser (BEFORE | AFTER side-by-side)
3. Hỏi user: có muốn commit không?
4. git commit → pre-commit hook tự động:
   - Extract tất cả measures → source/measures/
   - Skip eval nếu không có DAX thay đổi
   - Nếu có thay đổi: eval + preview + hỏi xác nhận y/n
5. Sau khi commit: hỏi user có muốn push không
6. git push → Jenkins tự deploy lên PBIRS 192.168.100.98
```

> **Bắt buộc:** File .pbix phải đang mở trong PBI Desktop RS khi commit.

---

## Scripts

| Script | Dùng khi |
|--------|----------|
| `scripts/patch_measure.ps1 -Action remove` | Xóa card/block khỏi measure expression |
| `scripts/restore_measure.ps1 -DaxFile <path>` | Restore measure từ file .dax |
| `scripts/extract_dax.ps1` | Extract measures từ live model ra source/ |
| `scripts/eval_measures.ps1` | Chạy measures → lưu HTML output vào %TEMP% |
| `scripts/generate_preview.py` | Tạo HTML preview before/after |
| `scripts/upload_pbirs.ps1` | Deploy .pbix lên PBIRS (Jenkins dùng) |

Config máy: `scripts/config.ps1` (gitignored) — copy từ `scripts/config.example.ps1`.

---

## Measures & Tables

| Measure | Table | File |
|---------|-------|------|
| `Provision_HTML` | `final_provision_report` | `source/measures/final_provision_report/Provision_HTML.dax` |
| `Provision_HTML_v2` | `final_provision_report` | `source/measures/final_provision_report/Provision_HTML_v2.dax` |
| `Repayment_HTML` | `final_repayment_report` | `source/measures/final_repayment_report/Repayment_HTML.dax` |
| `Disbursement_Summary_HTML` | `final_disbursement_consolidation` | `source/measures/final_disbursement_consolidation/Disbursement_Summary_HTML.dax` |
| `Disbursement_Monthly_HTML` | `final_monthly_disbursement_by_branch` | `source/measures/final_monthly_disbursement_by_branch/Disbursement_Monthly_HTML.dax` |
| `LoanSector_Daily_HTML` | `final_loan_sector_daily_report` | `source/measures/final_loan_sector_daily_report/LoanSector_Daily_HTML.dax` |
| `LoanSector_Yearly_HTML` | `final_loan_sector_yearly_report` | `source/measures/final_loan_sector_yearly_report/LoanSector_Yearly_HTML.dax` |
| `ExtraAccountable_HTML` | `final_extra_accountable_report` | `source/measures/final_extra_accountable_report/ExtraAccountable_HTML.dax` |
| `Provision_Comparison_HTML` | `provision_mock` | `source/measures/provision_mock/Provision_Comparison_HTML.dax` |

---

## Cards trong Provision_HTML_v2

Summary cards (block HTML ở đầu report):
- **Total Loans**
- **Total Outstanding**
- **Total Commitment**
- **Total Provision**
- **Outstanding Delta**

Khi user yêu cầu "gỡ Total Loans" → chạy:
```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts/patch_measure.ps1 -Action remove
```
`patch_measure.ps1` mặc định target `Provision_HTML` table `final_provision_report`.

Khi user yêu cầu "thêm lại Total Loans" hoặc "restore" → chạy:
```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts/restore_measure.ps1 `
  -DaxFile "source/measures/final_provision_report/Provision_HTML_v2.dax" `
  -Measure "Provision_HTML"
```

---

## Cache & baseline

`.measures_cache.json` lưu HTML output của tất cả measures tại thời điểm commit.
Pre-commit hook dùng `git show HEAD:.measures_cache.json` làm "before".

**Nếu preview hiện "No changes"** → cache cũ chưa có state "before" mong muốn.
Fix: restore measure về state có thay đổi → eval → commit cache → rồi mới sửa + preview.

---

## Environment

| | |
|--|--|
| PBIRS | `http://192.168.100.98/reports` |
| Auth | NTLM — credentials qua `$env:PBIRS_PASS` |
| PBI Desktop RS | `C:\Program Files\Microsoft Power BI Desktop RS` |
| Tabular Editor 2 | `C:\Program Files (x86)\Tabular Editor` |
| msmdsrv port | Động — detect tự động qua netstat |
