# Hướng dẫn sử dụng — PBIRS Report Pipeline

> Dành cho người dùng cuối, không yêu cầu kỹ thuật.

---

## Tổng quan hệ thống

Hệ thống này giúp bạn **sửa nội dung báo cáo Power BI** (ẩn/hiện card, chỉnh số liệu) thông qua AI, sau đó tự động lưu lịch sử thay đổi và đẩy lên server báo cáo.

```
Bạn ra lệnh → AI sửa trong PBI Desktop → Bạn kiểm tra → Commit → Push lên server
```

---

## Điều kiện bắt buộc trước khi bắt đầu

- [ ] **Power BI Desktop RS đang mở** với file báo cáo cần chỉnh
- [ ] File đã được mở đúng (thấy tên file trên thanh tiêu đề cửa sổ)

> Nếu PBI Desktop RS chưa mở → AI sẽ từ chối chạy và nhắc bạn mở trước.

---

## Cấu trúc thư mục

```
pbirs-report/
├── source/
│   └── measures/
│       ├── Credit Report/              ← DAX của file Credit Report.pbix
│       │   ├── final_provision_report/
│       │   │   └── Provision_HTML.dax
│       │   ├── final_repayment_report/
│       │   │   └── Repayment_HTML.dax
│       │   ├── final_extra_accountable_report/
│       │   │   └── ExtraAccountable_HTML.dax
│       │   ├── final_disbursement_consolidation/
│       │   │   └── Disbursement_Summary_HTML.dax
│       │   ├── final_monthly_disbursement_by_branch/
│       │   │   └── Disbursement_Monthly_HTML.dax
│       │   ├── final_loan_sector_daily_report/
│       │   │   └── LoanSector_Daily_HTML.dax
│       │   └── final_loan_sector_yearly_report/
│       │       └── LoanSector_Yearly_HTML.dax
│       └── BNCTL_Treasury_Reports/     ← DAX của file BNCTL_Treasury_Reports.pbix
│           ├── rpt_liquidity/
│           │   └── Liquidity_Measure.dax
│           ├── rpt_remittance_daily/
│           │   └── Report_Remittance_Incoming_SWIFT_IN.dax
│           └── rpt_remittance_quarterly/
│               └── Quarterly_Remittance_Report.dax
└── scripts/                            ← Công cụ tự động (không cần đụng trực tiếp)
```

> **Quy tắc:** Mỗi file `.pbix` có một thư mục riêng. Trong đó chứa DAX theo từng bảng.

---

## Luồng làm việc

### Trường hợp 1 — Ẩn một card khỏi báo cáo

**Ví dụ:** *"Tôi muốn gỡ card Total Write-Off khỏi báo cáo Extra Accountable"*

```
Bạn nhắn → AI chạy patch_measure.ps1 → Card bị ẩn trong PBI Desktop
           → Bạn kiểm tra trong PBI Desktop RS
           → Ổn → Bạn nói "OK commit"
           → AI commit (pre-commit hook tự extract DAX vào repo)
           → Bạn nói "Push lên server"
           → AI push → Server cập nhật
```

---

### Trường hợp 2 — Khôi phục card đã ẩn

**Ví dụ:** *"Add lại card Total Write-Off"*

```
Bạn nhắn → AI chạy restore_measure.ps1 với file .dax trong repo
          → Card hiện lại trong PBI Desktop
          → Bạn kiểm tra → Ổn → Commit → Push
```

---

### Trường hợp 3 — Repo và PBI Desktop bị lệch nhau

Xảy ra khi: ai đó sửa thẳng trong PBI Desktop mà không qua repo, hoặc mở file mới.

**Giải pháp:** Dùng lệnh `/pull-dax`

```
/pull-dax
```

```
AI chạy sync_repo_to_desktop.ps1
→ Ghi toàn bộ DAX từ repo vào Desktop model đang mở
→ Nhắc bạn Ctrl+S trong PBI Desktop RS để lưu vào file .pbix
```

> **Lưu ý:** Lệnh này ghi đè Desktop bằng repo. Repo là nguồn sự thật.

---

### Trường hợp 4 — Nhiều file .pbix đang mở cùng lúc

Khi 2 cửa sổ PBI Desktop RS mở cùng lúc, AI cần biết bạn muốn sửa file nào.

**Cách chỉ định:**
> *"Sửa card X trong **Credit Report**"*
> *"Pull DAX cho **BNCTL_Treasury_Reports**"*

AI sẽ tự map đúng cửa sổ và port tương ứng.

---

### Trường hợp 5 — Deploy lên server thủ công

Nếu không dùng CI/CD tự động:

```
Bạn nói "Push lên PBIRS" → AI chạy upload_pbirs.ps1
→ File .pbix được upload lên http://192.168.100.98/reports
```

---

## Bảng báo cáo và measure

### Credit Report

| Báo cáo | Measure | Thư mục |
|---------|---------|---------|
| Provision | `Provision_HTML` | `final_provision_report` |
| Provision v2 | `Provision_HTML_v2` | `final_provision_report` |
| Repayment | `Repayment_HTML` | `final_repayment_report` |
| Disbursement Summary | `Disbursement_Summary_HTML` | `final_disbursement_consolidation` |
| Disbursement Monthly | `Disbursement_Monthly_HTML` | `final_monthly_disbursement_by_branch` |
| Loan Sector Daily | `LoanSector_Daily_HTML` | `final_loan_sector_daily_report` |
| Loan Sector Yearly | `LoanSector_Yearly_HTML` | `final_loan_sector_yearly_report` |
| Extra Accountable | `ExtraAccountable_HTML` | `final_extra_accountable_report` |

### BNCTL Treasury Reports

| Báo cáo | Measure | Thư mục |
|---------|---------|---------|
| Liquidity | `Liquidity_Measure` | `rpt_liquidity` |
| Remittance Daily | `Report_Remittance_Incoming_SWIFT_IN` | `rpt_remittance_daily` |
| Remittance Quarterly | `Quarterly_Remittance_Report` | `rpt_remittance_quarterly` |

---

## Những điều AI không làm tự động

| Hành động | Cần xác nhận của bạn |
|-----------|----------------------|
| Commit lên Git | Bạn phải nói "OK commit" |
| Push lên server | Bạn phải nói "Push đi" |
| Tạo measure mới (chưa có file .dax) | Phải sửa thủ công trong PBI Desktop |

---

## Khi gặp sự cố

| Triệu chứng | Nguyên nhân | Cách xử lý |
|-------------|-------------|------------|
| AI báo lỗi "PBI Desktop RS not running" | Chưa mở file .pbix | Mở file trong PBI Desktop RS rồi thử lại |
| Sửa xong nhưng Desktop không thay đổi | Sai cửa sổ (nhiều file mở) | Nói rõ tên file muốn sửa |
| Repo và Desktop khác nhau | Desktop bị sửa tay | Chạy `/pull-dax` để đồng bộ |
| Commit xong server chưa cập nhật | Chưa push | Nói "Push lên PBIRS" |

---

## Môi trường

| | |
|--|--|
| PBIRS Server | `http://192.168.100.98/reports` |
| Git repo | `https://github.com/phamthanhhai003/pbirs-report` |
| PBI Desktop RS | `C:\Program Files\Microsoft Power BI Desktop RS` |
