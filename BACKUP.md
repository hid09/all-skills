# 衣橱数据备份说明

衣橱数据位于 `wardrobe/data/`，包括原图、缩略图、SQLite 数据库、结构化清单和回收站。

备份前先停止服务，避免 SQLite 的 WAL 文件仍在写入。然后运行：

```powershell
.\scripts\package-personal-bundle.cmd
```

恢复前建议备份目标电脑现有的 `wardrobe/data/`。恢复脚本只覆盖 `wardrobe/data/` 和 `context/`，不会删除项目代码。

