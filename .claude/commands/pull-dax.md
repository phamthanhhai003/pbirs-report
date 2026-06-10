# pull-dax

Ghi tất cả DAX từ repo (`source/measures/**/*.dax`) vào PBI Desktop RS đang chạy.
Dùng khi Desktop model lệch với repo — repo là source of truth.

## Khi nào dùng
- Mở PBI Desktop RS với file .pbix mới/reset
- Desktop bị sửa tay không qua repo
- Muốn đồng bộ repo → Desktop trước khi làm việc

## Thực thi

```bash
powershell.exe -ExecutionPolicy Bypass -File scripts/sync_repo_to_desktop.ps1
```

Sau khi chạy xong: **Save file trong PBI Desktop RS (Ctrl+S)** để ghi vào .pbix.
