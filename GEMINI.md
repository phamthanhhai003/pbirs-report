# PBIRS Report — AI Instructions

This repo contains DAX source files and the CI/CD pipeline for Power BI Report Server.
Read this file before doing anything related to reports.

---

## Operating Rules

1. **Before making any change**, verify Power BI Desktop RS is running:
   ```bash
   bash scripts/ps.sh -Command "Get-Process | Where-Object { \$_.MainWindowTitle -match 'Power BI Desktop' } | Select-Object MainWindowTitle"
   ```
   If no result → tell user to open the .pbix file in Power BI Desktop RS first.

2. **After editing DAX**, always follow this exact sequence:

   **Step A** — Apply to Desktop first:
   ```bash
   # Single measure (patch/restore):
   bash scripts/ps.sh -File scripts/restore_measure.ps1 -DaxFile "..." -Table "..." -Measure "..."
   # Multiple measures or new pbix:
   bash scripts/ps.sh -File scripts/sync_repo_to_desktop.ps1 -PbixName "..."
   ```

   **Step B** — Notify user to verify:
   > Change applied and auto-saved to Desktop. Open the report and check the result.

   **Step C** — After user confirms they have checked, present exactly **3 choices**:

   > Done reviewing? Choose:
   > 1. **Approve and push to server** — commit + push + upload to PBIRS
   > 2. **Keep editing** — describe the next change
   > 3. **Revert** — undo, restore to last committed state in repo

3. **If user picks 1**, run in sequence:
   ```bash
   # 1. Commit — SKIP_EXTRACT=1 skips extraction (already synced, no need)
   SKIP_EXTRACT=1 git commit -m "..."
   # 2. Push to Git remote (use Windows git for credential manager)
   bash scripts/ps.sh -Command "git -C 'D:\\pbirs-report' push"
   # 3. Upload .pbix to PBIRS (credentials hardcoded in config.ps1)
   bash scripts/ps.sh -File scripts/upload_pbirs.ps1
   ```

4. **If user picks 2**: wait for user to describe the next change, process it, then present 3 choices again.

5. **If user picks 3**: run `restore_measure.ps1` with the current `.dax` file in the repo to revert the measure to the last committed state. After revert, tell user to verify in Power BI Desktop RS.

6. **Never commit or push** without user confirmation.

---

## Request Recognition → Action

### User wants to hide / remove something from a report

→ Run `patch_measure.ps1` with the card label. Script **auto-scans all measures** — no need to specify a report:
```bash
bash scripts/ps.sh -File scripts/patch_measure.ps1 -CardLabel "Total Write-Off"
```
If the same card label appears in multiple reports, add `-Table` to narrow it down:
```bash
bash scripts/ps.sh -File scripts/patch_measure.ps1 -CardLabel "Total Write-Off" -Table "final_extra_accountable_report"
```
Works on any report with HTML cards in the pattern `<div>Label</div><div>Value</div>`.

→ **For other report types or complex changes:**
AI cannot edit DAX for those reports directly. Guide the user to:
- Open PBI Desktop RS → edit DAX directly → Ctrl+S → then `git commit`
- The pre-commit hook will auto-extract DAX into the repo

After every change (whether via script or manual), always present the **3 choices** per Rule 2.

### User wants to restore / add back something (or apply a DAX file change)

→ **Always pass all 3 params** — missing `-Table` causes the script to use the default `final_provision_report`, writing to the wrong measure with no visible error:
```bash
bash scripts/ps.sh -File scripts/restore_measure.ps1 \
  -DaxFile "source/measures/<pbix-name>/<table>/<measure>.dax" \
  -Table "<table>" \
  -Measure "<measure>"
```
`<pbix-name>` = name of the open .pbix (see **Pbix** column in the Measures table below).
Look up `<table>` and `<measure>` in the **Available Measures** table below.

### User wants to deploy to server

→ Commit first (if there are changes), then:
```bash
bash scripts/ps.sh -Command "git -C 'D:\\pbirs-report' push"
```
Jenkins auto-deploys on push (once Jenkins is configured).
Or upload manually:
```bash
bash scripts/ps.sh -File scripts/upload_pbirs.ps1
```

---

## AI Capabilities

| Can do | Cannot do |
|--------|-----------|
| Edit DAX for any report in the measures table | Create a brand-new DAX measure (no .dax file yet) |
| Hide / restore HTML cards via patch/restore scripts | Run while Power BI Desktop RS is closed |
| Extract, sync, deploy any open .pbix | Commit or push without user confirmation |
| Deploy any open .pbix to PBIRS | |

---

## Available Measures

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
| Page Number | `Page Number Value` | `PageNum` |

### BNCTL_Treasury_Reports (`source/measures/BNCTL_Treasury_Reports/`)

| Report | Measure | Table |
|--------|---------|-------|
| Liquidity | `Liquidity_Measure` | `rpt_liquidity` |
| Remittance Daily | `Report_Remittance_Incoming_SWIFT_IN` | `rpt_remittance_daily` |
| Remittance Quarterly | `Quarterly_Remittance_Report` | `rpt_remittance_quarterly` |

### Accounting (`source/measures/Accounting/`)

| Report | Measure | Table |
|--------|---------|-------|
| Liquidity | `Liquidity_HTML` | `final_liquidity_report` |
| Assets | `Assets_HTML` | `final_assets_report` |
| Balance Sheet Assets | `BS_Assets_HTML` | `final_balance_sheet_assets_report` |
| Balance Sheet Liabilities | `BS_Liabilities_HTML` | `final_balance_sheet_liabilities_report` |
| Income | `Income_HTML` | `final_income_report` |
| Expense | `Expense_HTML` | `final_expense_report` |
| Liabilities | `Liabilities_HTML` | `final_liabilities_report` |
| Ratio | `Ratio_HTML` | `final_ratio_report` |
| BCTL | `BCTL_HTML` | `final_bctl_report` |
| PO SIE | `PO_SIE_HTML` | `final_po_sie_report` |
| PO SOC | `PO_SOC_HTML` | `final_po_soc_report` |
| SIE | `SIE_HTML` | `final_sie_report` |
| SOC Liabilities | `SOC_Liabilities_HTML` | `final_soc_liabilities_report` |
| SOC Assets | `SOC_Assets_HTML` | `soc_assets_real_v2` |

DAX files: `source/measures/<pbix-name>/<table>/<measure>.dax`

---

## Environment

| | |
|--|--|
| PBIRS | `http://10.0.40.122/reports/browse/REPORT_V2` |
| PBI Desktop RS | `C:\Program Files\Microsoft Power BI Desktop RS` |
| Tabular Editor 2 | `C:\Program Files (x86)\Tabular Editor` |
| Machine config | `scripts/config.ps1` (gitignored) — copy from `config.example.ps1` |
| Repo root (Windows) | `D:\pbirs-report` |
| Repo root (WSL) | `/mnt/d/pbirs-report` |
| msmdsrv port | Auto-detected via netstat — never hardcoded |
| PS wrapper | `bash scripts/ps.sh` — works on WSL and Git Bash |
