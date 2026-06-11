# pull-dax

Sync all DAX measures from repo (`source/measures/**/*.dax`) into the open Power BI Desktop RS instance.
Use when Desktop model drifts from repo — repo is the source of truth.

## When to use
- Opened a new or reset .pbix in Power BI Desktop RS
- Desktop was edited manually (not through repo)
- Want to sync repo → Desktop before making changes

## Execute

```bash
cd /mnt/d/pbirs-report && powershell.exe -ExecutionPolicy Bypass -File scripts/sync_repo_to_desktop.ps1
```

If targeting a specific .pbix window (multiple files open), pass `-PbixName`:
```bash
powershell.exe -ExecutionPolicy Bypass -File scripts/sync_repo_to_desktop.ps1 -PbixName "Accounting"
```

Script reads from `source/measures/**/*.dax` in the current repo and applies each measure via AMO.
After completion: auto-saves the .pbix via Ctrl+S and uploads to PBIRS automatically.
