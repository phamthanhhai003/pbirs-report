# PBIRS Report — AI Instructions

DAX source files + CI/CD for Power BI Report Server. Read before any report work.

---

## Quick Reference

| Intent | Script |
|--------|--------|
| Hide/remove card | `patch_measure.ps1 -CardLabel "..."` |
| Restore/edit measure | `restore_measure.ps1 -DaxFile ... -Table ... -Measure ...` |
| Sync all repo → Desktop | `sync_repo_to_desktop.ps1 -PbixName "..."` |
| Upload to PBIRS | `upload_pbirs.ps1` |

All scripts: `bash scripts/ps.sh -File scripts/<script>.ps1 [params]`

---

## Flow (every change)

**1. Check PBI running:**
```bash
bash scripts/ps.sh -Command "Get-Process | Where-Object { \$_.MainWindowTitle -match 'Power BI Desktop' } | Select-Object MainWindowTitle"
```
No result → tell user to open .pbix first.

**2. Apply to Desktop:**
```bash
# Single measure:
bash scripts/ps.sh -File scripts/restore_measure.ps1 -DaxFile "..." -Table "..." -Measure "..."
# Multiple / new pbix:
bash scripts/ps.sh -File scripts/sync_repo_to_desktop.ps1 -PbixName "..."
```

**3. Notify user:**
> Change applied and auto-saved. Check the report and confirm.

**4. After user confirms, present 3 choices:**
> 1. **Approve and push** — commit + push + upload to PBIRS
> 2. **Keep editing** — describe next change
> 3. **Revert** — restore to last committed state

**Option 1 — invoke deploy skill:**
Call `Skill("deploy")` with a commit message derived from the change.

**Option 3 — revert:**
Run `restore_measure.ps1` with the `.dax` file from repo. Tell user to verify.

**Never commit or push without user confirmation.**

---

## Actions by Request

**Hide/remove card:**
```bash
bash scripts/ps.sh -File scripts/patch_measure.ps1 -CardLabel "Total Write-Off"
# Multiple reports with same label — add -Table:
bash scripts/ps.sh -File scripts/patch_measure.ps1 -CardLabel "Total Write-Off" -Table "final_extra_accountable_report"
```

**Restore/edit measure — always pass all 3 params** (missing `-Table` silently writes to wrong measure):
```bash
bash scripts/ps.sh -File scripts/restore_measure.ps1 \
  -DaxFile "source/measures/<pbix-name>/<table>/<measure>.dax" \
  -Table "<table>" -Measure "<measure>"
```

**Deploy only:**
```bash
bash scripts/ps.sh -Command "git -C 'D:\\pbirs-report' push"
# or manual upload:
bash scripts/ps.sh -File scripts/upload_pbirs.ps1
```

**Complex changes (no .dax file):** Guide user → edit DAX directly in PBI Desktop RS → Ctrl+S → `git commit` (hook auto-extracts).

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

DAX path: `source/measures/<pbix-name>/<table>/<measure>.dax`

---

## Environment

| | |
|--|--|
| PBIRS | `http://10.0.40.122/reports/browse/REPORT_V2` |
| PBI Desktop RS | `C:\Program Files\Microsoft Power BI Desktop RS` |
| Tabular Editor 2 | `C:\Program Files (x86)\Tabular Editor` |
| Config | `scripts/config.ps1` (gitignored) — copy from `config.example.ps1` |
| Repo (Windows) | `D:\pbirs-report` |
| Repo (WSL) | `/mnt/d/pbirs-report` |
| msmdsrv port | Auto-detected via netstat |
| PS wrapper | `bash scripts/ps.sh` — WSL + Git Bash |
