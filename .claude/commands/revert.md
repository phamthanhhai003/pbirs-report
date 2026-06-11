# revert

Undo the last DAX edit — restore .dax file to last committed state, then push back to Desktop.

## When to invoke
- User picks Option 3 ("Revert") after not approving a change
- AI calls this skill directly — user does not need to type /revert

## Input
`$ARGUMENTS` = the .dax file path that was just edited (e.g. `source/measures/Accounting/final_liquidity_report/Liquidity_HTML.dax`)

If no argument: ask user which measure to revert before proceeding.

## Execute in order

**Step 1 — Restore .dax to last committed state**
```bash
git checkout -- "$ARGUMENTS"
```

**Step 2 — Push restored DAX back to Desktop**
Extract table and measure name from the file path:
- Table = parent folder name
- Measure = filename without `.dax`

```bash
bash scripts/ps.sh -File scripts/restore_measure.ps1 \
  -DaxFile "$ARGUMENTS" \
  -Table "<table>" \
  -Measure "<measure>"
```

**Step 3 — Notify user**
> Reverted. Check the report in Power BI Desktop RS to confirm.
