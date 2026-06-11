# Power BI Report Server — User Guide

**For end users · No technical knowledge required**

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [First-Time Setup](#2-first-time-setup)
3. [Before Each Session](#3-before-each-session)
4. [Folder Structure](#4-folder-structure)
5. [Standard Workflow](#5-standard-workflow)
6. [Real-World Scenarios](#6-real-world-scenarios)
7. [Troubleshooting](#7-troubleshooting)
8. [System Environment](#8-system-environment)

---

## 1. System Overview

This system lets you **modify Power BI report content** using plain language instructions to an AI assistant — no coding, no DAX knowledge required. Once a change is made, the system automatically saves a history of the change and pushes the updated report to the internal report server.

### How It Works

```
You give an instruction in plain language
            ↓
     AI applies the change in Power BI Desktop RS
            ↓
     You verify the result directly in Power BI Desktop RS
            ↓
     Choose: Approve / Keep editing / Revert
            ↓
     If approved → History saved (Git) + Server updated automatically
```

### What the AI Can and Cannot Do

| The AI can | The AI cannot |
|------------|---------------|
| Hide or restore a card / metric | Create a brand-new measure from scratch |
| Edit the DAX expression of any existing measure | Commit or push without your confirmation |
| Sync the repo's DAX into an open Desktop model | Run while Power BI Desktop RS is closed |
| Deploy a report to the PBIRS server | |

---

## 2. First-Time Setup

Run this **once** on any new machine. Open PowerShell **as Administrator**, then:

```powershell
git clone <repo-url>
cd pbirs-report
powershell -ExecutionPolicy Bypass -File scripts/setup.ps1
```

The script will automatically:

| Step | What it installs / does |
|------|------------------------|
| 1 | **Git for Windows** — version control |
| 2 | **Node.js LTS** — required for Claude Code |
| 3 | **Claude Code CLI** — the AI assistant |
| 4 | **Tabular Editor 2** — DAX read/write engine (downloads from GitHub) |
| 5 | **Power BI Desktop RS** — prompts you if not found (requires manual install) |
| 6 | **config.ps1** — asks for your PBIRS server URL, username, and password |
| 7 | Git hooks — wires up the auto-extract pre-commit hook |

> **Power BI Desktop RS** cannot be installed silently. If the script prompts you, download and install it manually, then re-run `setup.ps1`.

After setup, the script prints:
```
  1. Open Power BI Desktop RS
  2. Open the .pbix file you want to edit
  3. Run: claude  (in this repo folder)
```

---

## 3. Before Each Session

### Step 1 — Open the report in Power BI Desktop RS

Launch **Power BI Desktop RS** and open the `.pbix` file you want to edit.

> **Check:** The window title bar should show the file name, for example:
> `Credit Report - Power BI Desktop (May 2025)`

If Power BI Desktop RS is not running, the AI will refuse any edit request and prompt you to open it first.

### Step 2 — Start a chat session with the AI

Open a terminal in the repo folder and run:

```
claude
```

Type your request in plain English.

### Step 3 — When multiple files are open

If you have two `.pbix` files open at the same time, always specify the file name in your request so the AI targets the correct window.

> **Correct:** *"Remove the Total Write-Off card from **Credit Report**"*
> **Ambiguous:** *"Remove the Total Write-Off card"* ← AI will ask which file

---

## 3. Folder Structure

All DAX source files are stored in the following structure. The AI manages these files automatically — you do not need to edit them directly.

```
pbirs-report/
│
├── source/
│   └── measures/
│       │
│       ├── Credit Report/                         ← Credit reporting .pbix
│       │   ├── final_provision_report/
│       │   │   ├── Provision_HTML.dax
│       │   │   └── Provision_HTML_v2.dax
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
│       │
│       └── BNCTL_Treasury_Reports/                ← Treasury reporting .pbix
│           ├── rpt_liquidity/
│           │   └── Liquidity_Measure.dax
│           ├── rpt_remittance_daily/
│           │   └── Report_Remittance_Incoming_SWIFT_IN.dax
│           └── rpt_remittance_quarterly/
│               └── Quarterly_Remittance_Report.dax
│
├── scripts/                                       ← Automation scripts (do not edit)
│   ├── extract_dax.ps1         — pulls DAX out of Desktop into repo
│   ├── patch_measure.ps1       — hides a card from a report
│   ├── restore_measure.ps1     — restores a card from the repo
│   ├── sync_repo_to_desktop.ps1 — writes repo DAX into Desktop model
│   └── upload_pbirs.ps1        — uploads .pbix to the report server
│
└── docs/
    └── user-guide-en.pdf       ← This document
```

> **Golden rule:** Each `.pbix` file has its own subfolder under `measures/`. The folder name matches the window title of that file in Power BI Desktop RS.

---

## 4. Standard Workflow

### Step 1 — Give the AI a plain-language instruction

You do not need to know technical terms. Describe what you want to change in the report.

**Examples of valid instructions:**

| You say | What happens |
|---------|-------------|
| *"Hide the Total Write-Off card in Extra Accountable"* | AI removes that card from the measure |
| *"Add back the Total Loans card"* | AI restores it from the saved repo file |
| *"Remove Total Overdue and Total NPL from Provision"* | AI removes both cards in one operation |

### Step 2 — AI applies the change

The AI runs the appropriate script (`patch_measure.ps1` or `restore_measure.ps1`) against the live Power BI Desktop model. The change is visible in the Desktop immediately.

### Step 3 — Verify in Power BI Desktop RS

Open (or switch to) Power BI Desktop RS. The updated report is shown live — no refresh needed. Check that the result looks correct.

### Step 4 — Choose what to do next

After every edit the AI presents exactly **three choices**. Nothing further happens until you pick one.

---

> **Edit complete. Open Power BI Desktop RS to review, then choose:**
>
> **1. Approve and push to server** — saves history and updates the server now
>
> **2. Keep editing** — describe the next change you want
>
> **3. Revert** — undo the change, restore to the last saved state in the repo

---

#### Choice 1 — Approve and push to server

The AI will save the change history to the Git repository and push the updated report to the Power BI Report Server. The report is live on the server immediately after.

#### Choice 2 — Keep editing

Describe your next change. The AI applies it and presents the three choices again. All changes in a session are bundled into a single commit when you finally approve.

#### Choice 3 — Revert

The AI runs `restore_measure.ps1` using the `.dax` file currently saved in the repo, restoring the measure to its last committed state. Power BI Desktop RS will reflect the reverted content immediately. The AI then prompts you to verify in Desktop.

---

## 5. Real-World Scenarios

### Scenario A — Hide a single card

**Goal:** Remove the "Total Write-Off" card from the Extra Accountable report.

**You say:**
> *"Remove the Total Write-Off card from Extra Accountable"*

**What happens:**
1. AI finds the "Total Write-Off" block inside `ExtraAccountable_HTML`
2. Hides the HTML block in the live Desktop model
3. Prompts you to check in Desktop RS
4. Presents the three choices

**You choose 1** → Changes saved to repo + report pushed to server.

---

### Scenario B — Restore a card that was previously hidden

**Goal:** Bring back the "Total Write-Off" card that was removed earlier.

**You say:**
> *"Add back the Total Write-Off card in Extra Accountable"*

**What happens:**
1. AI reads the `.dax` file from the repo (which still contains the full measure)
2. Writes it back into the Desktop model
3. Card reappears → presents three choices

---

### Scenario C — Make multiple changes before committing (Choice 2)

**You say:**
> *"Remove the Total Write-Off card from Extra Accountable"*

AI edits → You verify → **Choose 2 — Keep editing**

**You say:**
> *"Also remove Total Overdue"*

AI edits → You verify → **Choose 1 — Approve and push**

Both changes are saved in a single Git commit and pushed together.

---

### Scenario D — Undo a change (Choice 3)

**You say:**
> *"Remove the Total Loans card"*

AI edits → You check Desktop → Something looks wrong → **Choose 3 — Revert**

AI immediately restores the measure from the repo. The Total Loans card reappears in Desktop. No commit is made.

---

### Scenario E — Sync when Desktop is out of sync with the repo

**When this happens:** Someone edited a measure directly in Power BI Desktop (not through the AI), or you opened a fresh copy of the file.

**You say:**
> *"/pull-dax"*

**What happens:**
1. AI writes all `.dax` files from the repo into the currently open Desktop model
2. Reminds you to press **Ctrl+S** in Power BI Desktop RS to save to the `.pbix` file

> **Important:** The repo is always the source of truth. `/pull-dax` overwrites the Desktop model with whatever is in the repo.

---

### Scenario F — Two report files open at the same time

You have both `Credit Report` and `BNCTL_Treasury_Reports` open in separate windows.

**Always include the file name in your instruction:**

| You say | AI targets |
|---------|------------|
| *"Remove Total NPL from **Credit Report**"* | Credit Report window |
| *"Pull DAX for **BNCTL_Treasury_Reports**"* | BNCTL_Treasury_Reports window |
| *"Remove Total NPL"* | AI asks which file — slower |

---

### Scenario G — Deploy the report manually

If you want to push the current report to the server without making any DAX changes:

**You say:**
> *"Deploy to server"* or *"Push to PBIRS"*

The AI uploads the `.pbix` directly to the Power BI Report Server.

---

### Scenario H — Revert after a commit has already been made

If you approved a change (committed) but later realized it was wrong:

**You say:**
> *"Revert Provision_HTML to the previous version"*

The AI checks Git history, finds the last known good state, restores it to Desktop, and presents the three choices again.

---

## 6. Troubleshooting

### "PBI Desktop RS not running" / "Make sure the .pbix file is open"

Power BI Desktop RS is not open, or no file is loaded.

**Fix:**
1. Open Power BI Desktop RS
2. Open the `.pbix` file
3. Wait for the file to fully load (title bar shows the file name)
4. Retry your request

---

### Edit applied but nothing changed in Desktop

You have multiple `.pbix` windows open and the AI targeted the wrong one.

**Fix:** Include the file name explicitly in your instruction.
> *"Remove card X from **Credit Report**"*

---

### Desktop shows different content from the repo

The Desktop model was edited directly (not through the AI).

**Fix:**
> *"/pull-dax"* → AI overwrites Desktop with repo state → Press **Ctrl+S** in Desktop

---

### Committed but server not updated

The commit was made but the push/upload step was skipped.

**Fix:**
> *"Push to PBIRS"*

---

### Made a mistake and want to go back

If you are still in the current session (no commit yet):
- Choose **3 — Revert** when the AI presents the three options.

If you already committed:
> *"Revert [measure name] to the previous version"*

---

### The AI says it cannot find a card by that label

The card label in your instruction does not exactly match the label in the DAX.

**Fix:** Check the exact label spelling in Power BI Desktop, then retry with the exact text.

---

## 7. System Environment

| Component | Address / Path |
|-----------|---------------|
| PBIRS Server | *(to be filled)* |
| Git Repository | *(to be filled)* |
| Power BI Desktop RS | `C:\Program Files\Microsoft Power BI Desktop RS` |
| Tabular Editor 2 | `C:\Program Files (x86)\Tabular Editor` |
| Machine config | `scripts/config.ps1` (each machine creates its own copy) |

---

*Last updated: 2026-06-11*
