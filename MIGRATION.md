# 衣橱项目迁移说明

本项目分为公开代码包和个人迁移包。公开代码包不包含个人照片、数据库和风格上下文；个人迁移包用于把当前衣橱完整带到另一台电脑。

## 在当前电脑打包

先停止衣橱服务。在运行服务的窗口按 `Ctrl+C`，再从项目根目录运行：

```powershell
.\scripts\package-personal-bundle.cmd
```

默认会在 `dist/` 生成带日期的个人迁移压缩包。

## 在另一台电脑恢复

1. 安装 Node.js 22.5 或更高版本。
2. 克隆或复制本项目代码包。
3. 把个人迁移包复制到项目根目录。
4. 运行：

```powershell
.\scripts\restore-personal-bundle.cmd -ArchivePath .\my-wardrobe-private-YYYY-MM-DD.zip
```

5. 安装 Skill：

```powershell
.\install-skill.cmd
```

6. 启动衣橱：

```powershell
.\start.cmd
```

7. 在 Codex 中让 Agent 读取 `context/PROJECT_CONTEXT.md`。

## 数据安全

个人迁移包包含衣物原图、数据库和个人偏好，不能上传到公开 GitHub。建议使用加密压缩工具或可信的私密存储传输。打包脚本不会删除原目录，也不会修改衣橱数据。

## 共享范围

这种迁移方式不依赖局域网。每台电脑运行自己的本地副本；如果以后需要多台设备实时读写同一套数据，再单独部署带 HTTPS 和登录的远程服务。

