# deploy

Commit + push + upload to PBIRS. Option 1 of the post-edit flow.

## When to invoke
- User picks Option 1 ("Approve and push to server") after verifying in Desktop
- AI calls this skill directly — user does not need to type /deploy

## Input
`$ARGUMENTS` = commit message (required). If empty, generate one from `git diff --staged --stat`.

## Execute in order

**Step 1 — Commit (skip if nothing staged)**
```bash
git status --short
```
If output non-empty:
```bash
SKIP_EXTRACT=1 git commit -m "$ARGUMENTS"
```
If empty: note "nothing to commit, skipping" and continue.

**Step 2 — Push via Windows git (WSL has no credential manager)**
```bash
bash scripts/ps.sh -Command "git -C 'D:\\pbirs-report' push"
```

**Step 3 — Upload to PBIRS**
```bash
bash scripts/ps.sh -File scripts/upload_pbirs.ps1
```

## Report back
Show: commit hash (if committed) + push status + upload status. One line each.
