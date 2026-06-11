# PBIRS Report — AI Instructions

Repo này chứa source DAX + CI/CD pipeline cho Power BI Report Server.
Đọc file này trước khi làm bất cứ việc gì liên quan đến report.

---

## Nguyên tắc hoạt động

1. **Trước khi sửa bất kỳ thứ gì**, kiểm tra PBI Desktop RS đang chạy không:
   ```bash
   bash scripts/ps.sh -Command "Get-Process | Where-Object { \$_.MainWindowTitle -match 'Power BI Desktop' } | Select-Object MainWindowTitle"
   ```
   Nếu không có → báo user mở file .pbix trong PBI Desktop RS trước.

2. **Sau khi sửa DAX**, luôn thực hiện đúng thứ tự:

   **Bước A** — Apply vào Desktop trước:
   ```bash
   # Nếu sửa qua script patch/restore:
   bash scripts/ps.sh -File scripts/restore_measure.ps1 -DaxFile "..." -Table "..." -Measure "..."
   # Nếu sửa nhiều measure hoặc pbix mới:
   bash scripts/ps.sh -File scripts/sync_repo_to_desktop.ps1 -PbixName "..."
   ```

   **Bước B** — Nhắc user kiểm tra:
   > Đã apply và autosave vào Desktop. Mở report kiểm tra kết quả.

   **Bước C** — Sau khi user xác nhận đã xem, đưa ra **đúng 3 lựa chọn**:

   > Kiểm tra xong, chọn:
   > 1. **Đồng ý và đẩy lên server** — commit + push + upload PBIRS
   > 2. **Tiếp tục sửa** — báo muốn sửa thêm gì
   > 3. **Revert lại** — hoàn tác, khôi phục về trạng thái trong repo

3. **Nếu user chọn 1**: chạy tuần tự:
   ```bash
   # 1. Commit — SKIP_EXTRACT=1 bỏ qua extract (đã sync rồi, không cần)
   SKIP_EXTRACT=1 git commit -m "..."
   # 2. Push lên Git remote (dùng Windows git để có credential manager)
   bash scripts/ps.sh -Command "git -C 'D:\\pbirs-report' push"
   # 3. Upload .pbix lên PBIRS (credentials đã hardcode trong config.ps1)
   bash scripts/ps.sh -File scripts/upload_pbirs.ps1
   ```

4. **Nếu user chọn 2**: chờ user mô tả thay đổi tiếp theo, xử lý rồi lại đưa ra 3 lựa chọn.

5. **Nếu user chọn 3**: chạy `restore_measure.ps1` với file `.dax` hiện tại trong repo để revert measure về trạng thái đã commit gần nhất. Sau khi revert xong, nhắc user kiểm tra lại trong PBI Desktop RS.

5. **Không tự commit hoặc push** khi chưa được user xác nhận.

---

## Nhận diện yêu cầu → hành động

### User muốn xóa/ẩn một thứ gì đó khỏi report

→ Chạy `patch_measure.ps1` với tên card. Script **tự scan tất cả measures** tìm card đó, không cần chỉ định report:
```bash
bash scripts/ps.sh -File scripts/patch_measure.ps1 -CardLabel "Total Write-Off"
```
Nếu cùng tên card xuất hiện ở nhiều report, thêm `-Table` để giới hạn:
```bash
bash scripts/ps.sh -File scripts/patch_measure.ps1 -CardLabel "Total Write-Off" -Table "final_extra_accountable_report"
```
Works cho mọi report có card HTML dạng `<div>Label</div><div>Value</div>`.

→ **Nếu là report khác hoặc thay đổi phức tạp hơn:**  
AI không thể tự sửa DAX của report đó. Hướng dẫn user:
- Mở PBI Desktop RS → sửa DAX trực tiếp → Ctrl+S → rồi `git commit`
- Pre-commit hook sẽ tự extract DAX vào repo

Sau mỗi thay đổi (dù qua script hay hướng dẫn thủ công), luôn đưa ra **3 lựa chọn** theo Nguyên tắc 2.

### User muốn thêm lại / restore (hoặc áp dụng thay đổi DAX file)

→ **Luôn truyền đủ 3 tham số** — thiếu `-Table` → script dùng default `final_provision_report`, write sai measure, không có lỗi rõ ràng:
```bash
bash scripts/ps.sh -File scripts/restore_measure.ps1 \
  -DaxFile "source/measures/<pbix-name>/<table>/<measure>.dax" \
  -Table "<table>" \
  -Measure "<measure>"
```
`<pbix-name>` = tên .pbix đang mở (xem cột **Pbix** trong bảng Measures bên dưới).  
Tra `<table>` và `<measure>` trong bảng **Measures hiện có** bên dưới.

### User muốn deploy lên server

→ Commit trước (nếu có thay đổi), rồi:
```bash
git push
```
Jenkins tự deploy sau khi push (khi Jenkins đã setup).
Hoặc upload thủ công:
```bash
bash scripts/ps.sh -File scripts/upload_pbirs.ps1
```

---

## Giới hạn AI biết

| Có thể | Không thể |
|--------|-----------|
| Sửa DAX bất kỳ report nào trong bảng measures | Tự tạo DAX measure mới (chưa có .dax file) |
| Xóa/restore card HTML qua patch/restore script | Chạy khi PBI Desktop RS đóng |
| Extract, eval, preview bất kỳ report nào | Tự quyết commit/push không hỏi user |
| Deploy bất kỳ .pbix nào đang mở | |

---

## Measures hiện có

### Credit Report (`source/measures/Credit Report/`)

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

### BNCTL_Treasury_Reports (`source/measures/BNCTL_Treasury_Reports/`)

| Report | Measure | Table |
|--------|---------|-------|
| Liquidity | `Liquidity_Measure` | `rpt_liquidity` |
| Remittance Daily | `Report_Remittance_Incoming_SWIFT_IN` | `rpt_remittance_daily` |
| Remittance Quarterly | `Quarterly_Remittance_Report` | `rpt_remittance_quarterly` |

DAX files: `source/measures/<pbix-name>/<table>/<measure>.dax`

---

## Environment

| | |
|--|--|
| PBIRS | `http://10.0.40.122/reports/browse/REPORT_V2` |
| PBI Desktop RS | `C:\Program Files\Microsoft Power BI Desktop RS` |
| Tabular Editor 2 | `C:\Program Files (x86)\Tabular Editor` |
| Config máy | `scripts/config.ps1` (gitignored) — copy từ `config.example.ps1` |
| msmdsrv port | Tự detect qua netstat — không hardcode |
