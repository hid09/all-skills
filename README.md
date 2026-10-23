# all-skills · 个人 Agent Skills 套件

这是一个可复制到 GitHub 的个人 Agent Skills 仓库，包含三个可独立使用的 Skill：

- `wardrobe/`：本地浏览器衣橱录入与管理工具；
- `skills/wardrobe-stylist/`：给 Codex/Agent 使用的穿搭 Skill；
- `skills/flowmaker/`：单 HTML、零后端、可拖拽编辑的流程图 Skill；
- `skills/prism/`：多 AI / 多 Agent 交叉分析和议会式评审 Skill；
- 每个使用者默认拥有自己的 `wardrobe/data/`，照片和清单不会进入 Skill 文件夹。

## Skills 快速选择

| Skill | 适合 | 不适合 |
|---|---|---|
| `wardrobe-stylist` | 真实衣橱穿搭、趋势适配、风格校准、缺口和购物研究 | 自动购买、批量抓取登录限制页面 |
| `flowmaker` | 审批流、决策树、onboarding、系统步骤的可编辑网页图 | 只要静态 Mermaid、批量拓扑图 |
| `prism` | 复杂调研、方案比较、技术/商业决策、多专家交叉验证 | 简单问答、情绪问题、几秒内要答案的问题 |

三个 Skill 都只携带可复用说明、示例和脚本；个人照片、数据库、密钥和运行产物不进入公开包。

## 单独安装 Skill

把仓库地址交给 Agent，并指定需要安装的目录：

```text
请从这个仓库安装 skills/wardrobe-stylist、skills/flowmaker 或 skills/prism 到本机 Agent Skills 目录，并只安装我指定的 Skill。
```

衣橱 Skill 需要用户自行配置 `WARDROBE_URL` 或 `WARDROBE_DATA_DIR`；flowmaker 生成的 HTML 运行时需要访问 CDN；Prism 需要用户自行配置可信 Provider 和 API key。

## 给 Agent 的安装方式

把仓库地址交给 Agent，并说明：

> 请安装这个仓库里的 `skills/wardrobe-stylist` 到本机 Codex skills 目录，并在仓库的 `wardrobe/` 目录启动本地衣橱服务。

如果使用支持 skills 的安装器，也可以从仓库中的 `skills/wardrobe-stylist` 目录安装。安装完成后重新打开一个 Agent 会话，让 Skill 索引刷新。

在 Windows 上也可以直接在仓库根目录运行：

```powershell
install-skill.cmd
```

## 启动录入工具

要求 Node.js 22.5 或更高版本（推荐 Node.js 24+）。在仓库根目录执行：

```powershell
start.cmd
```

停止服务：在运行窗口按 `Ctrl+C`。如果端口 4173 已被占用，先停止旧的衣橱服务，或设置 `PORT` 后启动。

浏览器打开 <http://127.0.0.1:4173/>。

要让同一 Wi-Fi 下的其他设备访问：

```powershell
cd wardrobe
start-lan.cmd
```

然后用运行电脑的局域网 IPv4 地址访问，例如 `http://192.168.5.32:4173/`。服务运行在哪台电脑，数据就保存在哪台电脑。

## 个人数据

个人数据在 `wardrobe/data/`：原图、缩略图、SQLite 数据库和 `wardrobe.json` 都在这里。这个目录默认不应提交到公共 GitHub。迁移或备份时复制整个目录即可。

## 迁移到另一台电脑

如果需要把当前已经录入的衣橱带到另一台电脑，请先停止服务，再运行：

```powershell
.\scripts\package-personal-bundle.cmd
```

脚本会生成包含 `wardrobe/data/` 和 `context/` 的个人迁移包，默认输出到 `dist/`。这个压缩包包含个人照片和数据库，不应上传到公开 GitHub。

在另一台电脑的项目根目录运行：

```powershell
.\scripts\restore-personal-bundle.cmd -ArchivePath .\my-wardrobe-private-YYYY-MM-DD.zip
```

完整流程见 [MIGRATION.md](MIGRATION.md)，备份注意事项见 [BACKUP.md](BACKUP.md)。

Skill 优先读取正在运行的本地服务；也可以通过 `WARDROBE_URL` 指定服务地址，服务不可用时回退读取项目中的 `wardrobe/data/wardrobe.json`。

## 当前能力边界

录入工具负责真实衣物、照片标签、分类、排序、回收站和清单导出。Skill 负责审美校准、基于真实衣橱的穿搭、天气与场景适配、风格参考研究、衣橱缺口和购物候选。它不会自动下单，也不会把参考图片中的模特衣物当成用户已有衣物。
