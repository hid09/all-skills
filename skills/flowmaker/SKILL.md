---
name: flowmaker
description: 生成单 HTML、零后端、可拖拽编辑的网页流程图。Use when 用户要把流程、审批流、决策树、onboarding 或系统步骤做成可编辑网页图，并需要节点、连线、判断分支、保存或导出。先生成并校验 nodes/edges JSON，再注入模板。不要用于只要静态 Mermaid/图片、批量服务端渲染或复杂网络拓扑的请求。
---

# flowmaker — 单 HTML 网页流程图生成器

把一段流程描述，变成一个**单 HTML 交付文件（运行时需联网加载 CDN）**：浅色 ppvi 玻璃风、可拖拽编辑、零后端、双击文件即开。引擎（React Flow + dagre + 三形状）已封装在本目录的 `template.html`，你只需产出流程的 JSON 数据并注入模板。

## 工作流

1. **判断是否适用**：需要浏览器内可编辑的流程图才使用本 Skill；静态图优先 Mermaid。
2. **澄清流程**（信息不足时）：起点/终点、关键步骤、判断分支、各分支去向。只追问会改变图结构的问题。
3. **建数据**：把流程拆成 `nodes` + `edges`，写成下方 schema 的 JSON。
   - 优先**省略坐标**，让 dagre 自动布局（最省事，任意流程都能排）。
   - 只有要精确复刻某个版式时才手动给 `x`/`y`（给了坐标就不触发自动布局）。
4. **校验数据**：运行 `validate-flowmaker.ps1 -Path <html>`；检查节点 ID 唯一、边引用存在、判断节点有分支标签、图中没有意外孤立节点。
5. **生成文件**：复制本目录的 `template.html` → 替换 `<script id="flow-data">` 和 `<title>` → 另存为 `outputs/{YYYY-MM-DD}-{主题}-flowchart.html`。
6. **打开验证**：确认节点、连线、菱形、拖拽、编辑、保存和导出均可用；复杂回流图要在交付说明中标注布局限制。

详细字段规则见 [references/flow-schema.md](references/flow-schema.md)，复杂布局处理见 [references/layout-guidance.md](references/layout-guidance.md)。

## 数据 Schema

```json
{
  "title": "顶栏标题",
  "subtitle": "顶栏副标题（可省略）",
  "direction": "TB",
  "nodes": [
    { "id": "唯一id", "title": "主标题", "sub": "子标题/概述(可省)", "kicker": "小标签(可省)",
      "detail": "点「详情 ▾」弹层显示的长内容(可省，支持多行)",
      "shape": "process|terminator|decision", "variant": "|start|gold|muted",
      "x": 0, "y": 0 }
  ],
  "edges": [
    { "source": "id", "target": "id", "label": "线上文字(可省)",
      "dashed": false, "sh": "b", "th": "t" }
  ]
}
```

字段说明：

| 字段 | 取值 | 含义 |
|---|---|---|
| `shape` | `process`（默认，矩形）/ `terminator`（起止，圆角条）/ `decision`（判断，扁菱形） | 节点形状 |
| `variant` | 空（普通）/ `start`（蓝，起点）/ `gold`（金，强调/终点）/ `muted`（灰虚线，弱化/失败分支） | 配色 |
| `kicker` | 短文本 | 节点上方小标签；**菱形节点会自动隐藏 kicker/sub，只显示一行灰色小字**，所以判断节点只写 `title` |
| `detail` | **HTML 字符串** | 节点显示「详情 ▾」按钮，点开浮层模态看完整内容。**详细攻略/命令/配置放这里，节点本身只写概述**，避免撑乱排版。按 HTML 渲染：`<a href target="_blank">` 可点链接、`<pre><code>` 代码块、`<span class="os win/mac">` 区分系统、`<ul>/<p>/<b>`、`<span class="tip">` 提示框。攻略类要详细、分 Windows/macOS、把用户当小白、多写解释 |
| `dashed` | true/false | 虚线（用于"否/出局/失败"等弱分支），自动取消流动动画 |
| `sh`/`th` | `t/b/l/r`（默认 `b`→`t`） | 连线接哪个 handle；侧向分支用 `"sh":"r","th":"tl"` 走右侧更顺 |
| `x`/`y` | 数字 | 手动坐标；**全部节点都给才生效**，否则整体走 dagre 自动布局 |

## 形状用法约定

- **起点 / 终点** → `terminator`（起点配 `start` 蓝，终点配 `gold` 金）
- **普通步骤** → `process`
- **判断 / 分支点** → `decision`，title 用问句（"通过审核？"），向外引两三条带 `label`（"是"/"否"）的边，弱分支加 `dashed`
- 主干尽量用同一套 handle（默认 b→t）走直线；侧向分支才用 `r`/`tl`

## 排版控制（节点别太胖）

节点宽度固定、**高度随内容自适应**。控制高度靠内容，不靠改尺寸：

- 节点上只放<b>概述</b>：`title` 一行 + `sub` 一行短句（≤ ~10 字，避免换行撑高）。
- 详细内容（命令、配置、分系统说明）全放 `detail` 浮层，别堆在 `sub`。
- 起止节点（terminator）尤其要短：`title` 一行，长描述移到 `sub` 或 `detail`，否则圆角卡片会变高。

## 交互（产物自带，无需额外代码）

拖动节点 · 从节点圆点拖出新连线 · 双击节点开编辑面板（改 kicker/标题/子标题/形状/配色） · 单击连线改线上文字 · 面板内删节点/删连线 · Delete 键删 · ＋添加节点。

**保存与导出**（顶栏按钮）：
- 💾 **保存**（或 `Ctrl+S` / `Cmd+S`）：手动写入浏览器 localStorage —— 同浏览器打开同一份初始流程时下次仍在（保存键由标题和初始图结构指纹组成），关电脑/重启不丢；**跨浏览器、换电脑、文件改名都会失效**，要发同事就点 📤 HTML。
- 📤 **HTML**：把当前画布（含所有改动）打包成单 HTML 下载，文件名自动加 `.v1.html` / `.v2.html` 递增版本号；下载的文件双击即开；仍需联网加载 CDN。
- 🖼 **导出 PNG**：高清截图。

**升级历史 HTML**（让老产物也能用 💾 保存 / 📤 HTML）：跑 `upgrade-flowmaker.ps1`，老文件原样保留，生成 `xxx.upgraded.html` 同目录新版。
```powershell
# 单文件
.\upgrade-flowmaker.ps1 -Path "C:\path\to\old.html"
# 整个目录批量
.\upgrade-flowmaker.ps1 -Path "C:\path\to\outputs"
```

## 技术说明

- 单文件，运行时通过 esm.sh CDN 加载 React 18 / @xyflow/react 12 / @dagrejs/dagre 1 / htm，**无构建、无后端**，需联网拉 CDN。
- 自动布局用 dagre（`direction` 控制 TB/LR/RL/BT）。
- 视觉为浅色 ppvi：玻璃磨砂节点、金/蓝/灰状态色、判断菱形为 SVG 多边形（均匀描边、不会在锐角处糊成灰块）。

模板内置示例可直接打开；本仓库当前不附带 examples 目录。
