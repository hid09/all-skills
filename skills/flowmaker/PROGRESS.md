# flowmaker 优化进度记录

> 老大高频使用 flowmaker，2026-06-23 启动一轮优化。这份文档归档**已做的工作、踩过的坑、未完成的探索**，方便未来接续。

---

## 1. 起因（用户痛点）

老大反馈三个问题：

1. **修改保存** —— 改完刷新就丢，没有任何持久化出口。
2. **排版凌乱** —— dagre 默认参数下，节点宽度写死、新加节点堆左上角。
3. **连线缠绕** —— 多分支汇聚、回流（环边）、判断节点"是/否"方向混乱。

---

## 2. 调研结论（关键，别再重新调研）

详细调研报告（路径优化、布局引擎对比、生产案例）由 sub-agent 完成，要点摘录：

| 问题 | 根因 | 谁的锅 |
|---|---|---|
| 判断节点是/否方向乱 | dagre **没有"端口"概念**，无法约束某条边从哪个方向走 | dagre 设计如此 |
| 回流被绕成诡异折线 | dagre 用 Sugiyama 分层，反向边会反转+插虚拟节点 | dagre 固有局限 |
| 多入边路径重叠 | dagre 不做"边-边平行偏移"（parallel edge nudging） | dagre + smoothstep 双重局限 |

**关键背景**：
- React Flow 团队官方表态："**dagre 适合树，elkjs 适合复杂图**"。
- 原 `dagre` 包已停滞，**`@dagrejs/dagre`** 是 2025 年活跃 fork（v3，~218 万周下载）。
- ELK 的 `cycleBreaking.strategy` + `edgeRouting: ORTHOGONAL` 是治回流和正交路由的特效药。
- 业界用 React Flow + ELK 的代表项目：**Reaflow / n8n / Activepieces / Typebot**。

### 候选方案（4 个）

| 方案 | 解决场景 | 改造成本 | 体积 |
|---|---|---|---|
| **A**：保留 dagre + `@jalez/react-flow-smart-edge` | 部分多入边重叠 | 小 | 增量小 |
| **B**：换 elkjs + 端口约束（推荐） | 全部三个场景 | 中（半天活） | 1.5MB（gzip 350KB） |
| **C**：换 cytoscape.js | 全部 | 大（重写） | 大 |
| **D**：保持 dagre + 产品约束（禁环、显式选方向） | 部分 | 小 | 0 |

---

## 3. 已尝试（v2 / v3 探索资产）

### `template.v2.html`（dagre + 多 handle + 完整新功能）
- 保留 dagre 布局
- 节点加 12 个 handle（每边 3 槽：center + 偏左/偏右），按"对端坐标"智能分配
- 加全套新功能：保存 / 导出 HTML / 导出 JSON / 导入 JSON / 重排 / 方向切换 / 帮助层
- **问题**：handle 分槽只在端点不撞，中段路径仍可能重叠；判断节点方向仍不可控；回流仍诡异
- **状态**：保留作为"全功能版"参考；老大最终决定只要保存+导出 HTML，其他功能精简掉

### `template.v3.html`（ELK 集成尝试）
- 在 v2 基础上引入 elkjs（懒加载，失败回退 dagre）
- 用 ELK 的 `portConstraints: FIXED_SIDE` 锁判断节点方向
- ORTHOGONAL 路由 + DEPTH_FIRST cycleBreaking

**翻车点（这是未来重做时必须避开的坑）**：

| 翻车点 | 表现 | 根因 | 启发 |
|---|---|---|---|
| 主干偏斜 | 整条流程被掰到一侧 | 给"是"分支强制 EAST port，下游节点全跟着右移 | **不能简单"是→右、否→左"**；流程图惯例是"是→主干、否→侧分支" |
| 边静默丢失 | rev3 节点孤立、断层 | React Flow 渲染时找不到对应 handle 就**静默丢边** | 必须做 **handle 白名单 sanitize**，找不到就 fallback 到中心 |
| 虚线扩散 | 保存往返后所有边变虚线 | `serializeState` 用 `e.style?.strokeDasharray` 判断 dashed，但 `animated:true` 也注入 dasharray | **只信 `e.data.dashed`，不信 style** |
| handle 映射硬编码 | 判断节点出边走的方向跟 ELK 算出的位置不匹配 | 我把 yes/no handle 硬写 `b`/`tl`，没跟随 ELK 实际位置 | 所有 handle 都得**按 ELK 算出的 dx/dy 动态选** |

**状态**：探索性代码，已修到"线不撞了但流程结构断层"，老大叫停。代码留作未来重做时的起点。

---

## 4. 最终落地（v3.1，2026-06-23）

老大决定：**精简路线**。

- **不动布局引擎**（保持 dagre，所有已知限制接受）
- **只加 2 个按钮**：💾 保存（手动 / Ctrl+S）+ 📤 导出 HTML（自动 v1/v2 版本号）
- **不要自动保存**（避免误操作）
- **不要方向切换 / 重排 / 导入 / JSON 导出 / 帮助层**

### 实现要点
- localStorage key：`flowmaker:v1:<title-hash>`，按流程图标题哈希隔离
- 导出文件名：`<原标题>.v1.html` / `.v2.html`...，用 localStorage 记每个 key 的下一个版本号
- 关掉浏览器、重启电脑后，**同一浏览器、同一文件路径**打开 → 改动还在
- 跨浏览器/跨电脑/换路径 → 失效，要靠 📤 导出 HTML 留底

---

## 5. 资产清单

```
<skills-root>\flowmaker\
├── template.html              ← 现役（加了 2 按钮的最终版）
├── template.v1.bak.html       ← 改造前的原版备份（一键回退）
├── template.v2.html           ← 探索资产：dagre + 多 handle + 全功能版
├── template.v3.html           ← 探索资产：ELK 集成尝试（半成品）
├── SKILL.md                   ← 已更新（加了 1 行说明）
└── PROGRESS.md                ← 本文档
```

---

## 6. 未来要重启 ELK 方案时，从这里入手

1. **先读这份文档的 "翻车点" 表**，把那 4 个坑列入 must-fix
2. **起点用 `template.v3.html`**，已经把 ELK 懒加载 + dagre 兜底框架搭好了
3. **关键改动**：
   - 不要用 `portConstraints: FIXED_SIDE`，改用 "yes 走主干、no 走侧"
   - 所有 handle 映射用 `sanitizeHandle` 兜底
   - `serializeState` 只信 `e.data.dashed`
   - handle 选择全部按 ELK 实际算出的 dx/dy 决定，不能硬编码
4. **测试集**：用 `test-v3.html`（已经删除）的 13 节点 15 边审批流，含**回流 + 多入边 + 三层判断**，是最毒的测试用例

---

## 7. 沉淀的规则（已加入老大的 CLAUDE.md 规则）

[2026-06-23] **JS 字符串里出现 `</script>` 必须拆开写**（如 `'<' + '/script>'`），HTML 解析器看到完整序列会提前关闭 script 标签，导致后续 JS 全废。

[2026-06-23] **PowerShell 写文件给浏览器读时，必须用 UTF-8 with BOM**：`$utf8Bom = New-Object System.Text.UTF8Encoding $true; [System.IO.File]::WriteAllText($p, $t, $utf8Bom)`。否则 `file://` 协议下 Chrome/Edge 会按 GBK 猜测 → 中文乱码。

[2026-06-23] **React Flow 的 edge 渲染会因 handle 不存在而静默丢失**，map handle 时一定要白名单兜底。
