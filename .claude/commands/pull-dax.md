# pull-dax

Ghi tất cả DAX từ repo (`source/measures/**/*.dax`) vào PBI Desktop RS đang chạy.
Dùng khi Desktop model lệch với repo — repo là source of truth.

## Khi nào dùng
- Mở PBI Desktop RS với file .pbix mới/reset
- Desktop bị sửa tay không qua repo
- Muốn đồng bộ repo → Desktop trước khi làm việc

## Thực thi

```bash
cd /mnt/d/pbirs-report && powershell.exe -ExecutionPolicy Bypass -File scripts/sync_repo_to_desktop.ps1
```

Script đọc từ `source/measures/**/*.dax` trong repo hiện tại.
Sau khi chạy xong: **nhắc user Ctrl+S trong PBI Desktop RS** để ghi vào .pbix.
