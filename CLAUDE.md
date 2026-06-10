# PBIRS Report — AI Instructions

Repo này chứa source DAX + CI/CD pipeline cho Power BI Report Server.
Đọc file này trước khi làm bất cứ việc gì liên quan đến report.

---

## Nguyên tắc hoạt động

1. **Trước khi sửa bất kỳ thứ gì**, kiểm tra PBI Desktop RS đang chạy không:
   ```bash
   powershell.exe -Command "Get-Process | Where-Object { \$_.MainWindowTitle -match 'Power BI Desktop' } | Select-Object MainWindowTitle"
   ```
   Nếu không có → báo user mở file .pbix trong PBI Desktop RS trước.

2. **Sau khi chạy `patch_measure.ps1` hoặc `restore_measure.ps1`**, PostToolUse hook tự chạy eval + preview. AI **không tự chạy thêm** eval hay preview — sẽ bị chạy đôi.

3. **Sau khi preview mở**, hỏi user: *"Preview ổn chưa? Muốn commit không?"*

4. **Sau khi commit**, hỏi user: *"Muốn push lên PBIRS không?"*

5. **Không tự commit hoặc push** khi chưa được user xác nhận.

---

## Nhận diện yêu cầu → hành động

### User muốn xóa/ẩn một thứ gì đó khỏi report

→ Chạy `patch_measure.ps1` với tên card. Script **tự scan tất cả measures** tìm card đó, không cần chỉ định report:
```bash
powershell.exe -ExecutionPolicy Bypass -File scripts/patch_measure.ps1 -CardLabel "Total Write-Off"
```
Nếu cùng tên card xuất hiện ở nhiều report, thêm `-Table` để giới hạn:
```bash
powershell.exe -ExecutionPolicy Bypass -File scripts/patch_measure.ps1 -CardLabel "Total Write-Off" -Table "final_extra_accountable_report"
```
Works cho mọi report có card HTML dạng `<div>Label</div><div>Value</div>`.

→ **Nếu là report khác hoặc thay đổi phức tạp hơn:**  
AI không thể tự sửa DAX của report đó. Hướng dẫn user:
- Mở PBI Desktop RS → sửa DAX trực tiếp → Ctrl+S → rồi `git commit`
- Pre-commit hook sẽ tự extract + preview

### User muốn thêm lại / restore

→ Restore từ file .dax đã lưu:
```bash
powershell.exe -ExecutionPolicy Bypass -File scripts/restore_measure.ps1 \
  -DaxFile "source/measures/final_provision_report/Provision_HTML_v2.dax" \
  -Measure "Provision_HTML"
```

### User muốn xem preview hiện tại (không commit)

→ Chạy eval + generate preview thủ công:
```bash
powershell.exe -ExecutionPolicy Bypass -File scripts/eval_measures.ps1
WIN_TEMP=$(powershell.exe -Command 'Write-Host $env:TEMP' 2>/dev/null | tr -d '\r')
WSL_TEMP=$(wslpath "$WIN_TEMP")
python3 scripts/generate_preview.py "$WSL_TEMP/pbirs_measures.json" "$WSL_TEMP/pbirs_preview.html"
explorer.exe "$(wslpath -w "$WSL_TEMP/pbirs_preview.html")"
```

### User muốn deploy lên server

→ Commit trước (nếu có thay đổi), rồi:
```bash
powershell.exe -Command "git -C 'D:\pbirs-report' push 2>&1"
```
Jenkins tự deploy sau khi push (khi Jenkins đã setup).
Hoặc upload thủ công:
```bash
powershell.exe -ExecutionPolicy Bypass -File scripts/upload_pbirs.ps1
```

### Preview hiện "No changes" dù đã sửa

→ Cache baseline chưa đúng. Fix:
```
1. Restore measure về state CÓ thay đổi mong muốn
2. Chạy eval → commit cache (git commit -m "cache: baseline")
3. Mới sửa + chạy preview
```

---

## Giới hạn AI biết

| Có thể | Không thể |
|--------|-----------|
| Sửa Provision_HTML (xóa/restore card) | Sửa DAX của report khác (Repayment, Disbursement...) |
| Extract, eval, preview bất kỳ report nào | Tự tạo DAX measure mới |
| Deploy bất kỳ .pbix nào đang mở | Chạy khi PBI Desktop RS đóng |
| Commit + push | Tự quyết commit/push không hỏi user |

---

## Measures hiện có

| Report | Measure | Table |
|--------|---------|-------|
| Provision | `Provision_HTML` | `final_provision_report` |
| Provision v2 | `Provision_HTML_v2` | `final_provision_report` |
| Repayment | `Repayment_HTML` | `final_repayment_report` |
| Disbursement Summary | `Disbursement_Summary_HTML` | `final_disbursement_consolidation` |
| Disbursement Monthly | `Disbursement_Monthly_HTML` | `final_monthly_disbursement_by_branch` |
| Loan Sector Daily | `LoanSector_Daily_HTML` | `final_loan_sector_daily_report` |
| Loan Sector Yearly | `LoanSector_Yearly_HTML` | `final_loan_sector_yearly_report` |
| Extra Accountable | `ExtraAccountable_HTML` | `final_extra_accountable_report` |

DAX files: `source/measures/<table>/<measure>.dax`

---

## Environment

| | |
|--|--|
| PBIRS | `http://192.168.100.98/reports` |
| PBI Desktop RS | `C:\Program Files\Microsoft Power BI Desktop RS` |
| Tabular Editor 2 | `C:\Program Files (x86)\Tabular Editor` |
| Config máy | `scripts/config.ps1` (gitignored) — copy từ `config.example.ps1` |
| msmdsrv port | Tự detect qua netstat — không hardcode |
