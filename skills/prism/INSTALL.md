# Prism V4.2 安装与初始化

配置前请先运行 `git status`，确认没有意外提交 API key 或本地密钥文件。

## 推荐方式

首次使用先运行初始化向导：

```powershell
pwsh ~/.claude/skills/prism/scripts/init-prism.ps1
```

Windows PowerShell 也可运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/prism/scripts/init-prism.ps1
```

向导会生成：

- `~/.prism/providers.json`
- `~/.prism/models.local.json`
- `~/.prism/keys.env`

## 手工配置

参考：

- `config/providers.example.jsonc`
- `config/providers.schema.json`
- `config/models.schema.json`

API key 不允许写进任何 JSON 文件，只能写在环境变量、`~/.prism/keys.env` 或 `scripts/keys.env`。

## Key 与 Base URL 读取顺序

`panel.ps1` 严格按以下顺序读取：

1. process env
2. `~/.prism/keys.env`
3. `~/.claude/skills/prism/scripts/keys.env`

找到即停。`base_url` 对应的 `PRISM_XXX_BASE` 也遵守同一顺序。

## 默认档位

- `/prism 问题`：默认 deep
- `/prism 问题 --deep`：deep
- `/prism 问题 --standard`：standard

没有 lite 档，没有 quick 档，没有 mode 分流。

安全默认：`panel.ps1` 默认清空输出中的 `raw_content`。只有在本机短期排障且确认文件不会外传时，才显式使用 `-IncludeRawContent`；该选项可能包含用户输入或供应商返回的敏感内容。
