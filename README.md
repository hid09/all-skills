# all-skills · Agent Skills 与衣橱穿搭套件

这里提供三个 Skill。其中，衣橱工具与 `wardrobe-stylist` 配套使用：安装后上传自己的衣服图片，再让 Agent 根据真实衣橱给出穿搭建议。

| 能力 | 入口 | 用途 |
|---|---|---|
| 衣橱穿搭套件 | `wardrobe/` + `skills/wardrobe-stylist/` | 图片录入、衣橱管理、穿搭建议、趋势适配与购物缺口分析 |
| 可编辑流程图 | [flowmaker](skills/flowmaker/SKILL.md) | 生成可拖拽编辑、保存和导出的单 HTML 流程图 |
| 多专家协作分析 | [prism](skills/prism/SKILL.md) | 复杂调研、方案比较和保留分歧的多 AI 分析 |

## 衣橱套件：交给 Agent 安装

将下面的提示词发给支持本地文件和终端操作的 Agent：

```text
请从 https://github.com/hid09/all-skills.git 安装衣橱穿搭套件。
克隆仓库，检查 Node.js 22.5 或以上版本；安装完整的
skills/wardrobe-stylist 目录到当前 Agent 支持的 Skills 目录，
并启动仓库中的 wardrobe/app/server.js。
保留衣橱工具和 Skill 的配套关系，不要只安装 Skill 后就结束。
配置 WARDROBE_URL 指向实际服务地址，验证 /api/health 和 /api/wardrobe。
打开衣橱网页，告诉我如何上传第一件衣物，再根据我的真实单品提供穿搭建议。
新用户使用自己的空衣橱，不需要任何个人迁移包。
```

## 手动安装与启动

要求 Node.js 22.5 或以上版本，推荐 24+。下载仓库后，在仓库根目录执行：

```powershell
git clone https://github.com/hid09/all-skills.git
cd all-skills
node scripts/install-skill.mjs
node wardrobe/app/server.js
```

安装脚本默认安装到 Codex Skills 目录；其他 Agent 请将完整的 `skills/wardrobe-stylist/` 安装到其支持的 Skills 目录。安装后可能需要重新打开 Agent 会话。

Windows 也可以先运行 `install-skill.cmd`，再运行 `start.cmd`。

浏览器打开 <http://127.0.0.1:4173/>。停止服务时，在运行窗口按 `Ctrl+C`。若端口已被占用，请检查现有服务，或设置 `PORT` 并同步调整 `WARDROBE_URL`。

## 上传图片并开始穿搭

1. 在网页点击“＋ 添加”或“添加第一件衣物”，上传自己的衣物照片。
2. 同一件衣物的实拍、模特和详情图放在同一个单品里；一次上传多张照片默认组成一个单品，不同衣物请分别添加。
3. 在照片下选择来源标签，补充名称、分类等资料后保存。首张照片用作列表首图。
4. 对 Agent 说：“读取我的本地衣橱，根据我的城市、天气和场合，给我三套不同风格的穿搭。”首次使用可先填写风格偏好。

Skill 优先读取本地服务。默认地址为 `http://127.0.0.1:4173`；服务地址不同时配置 `WARDROBE_URL`。也可用 `WARDROBE_DATA_DIR` 指向自己的数据目录。

需要当前趋势时，可以请求分析可访问的小红书等公开参考，或提供链接、截图；访问受限时不会绕过限制或编造趋势来源。

## 数据与能力边界

每位使用者的照片、数据库和清单保存在自己的 `wardrobe/data/`，不会随公开仓库分发，也不应提交到 GitHub。新安装从空衣橱开始。

录入工具负责单品、照片、分类、排序和回收站；Skill 负责搭配、风格校准、趋势适配与购物研究。参考图里的衣物不会被当成已有单品，Skill 不自动下单。

默认服务仅限本机访问。同一可信网络内上传图片的方式与访问边界见 [衣橱工具说明](wardrobe/README.md)。

## 其他 Skill

只需要流程图或多专家分析时，可以分别安装 `skills/flowmaker/` 或 `skills/prism/`，无需启动衣橱工具。

- flowmaker：生成的 HTML 运行时需要访问 CDN。
- Prism：需自行配置可信 Provider 和 API key，配置步骤见 [INSTALL.md](skills/prism/INSTALL.md)。
