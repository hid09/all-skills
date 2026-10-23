# 私有 Skills 专家审计报告

审计日期：2026-10-24

范围：仅审计我们自己做的或做过二次开发的三个 Skill。

## 结论

三个 Skill 均达到“可对外分享候选”标准：入口清晰、核心问题有对应能力、默认行为和隐私边界已补齐。发布前仍需要在目标环境完成一次真实冒烟测试，不能把本机配置当成通用配置。

## flowmaker

入口：`C:\Users\admin\.agents\skills\flowmaker\SKILL.md`

已修复：错误的模板路径、联网依赖未说明、同标题流程 localStorage 串档、导出 HTML 标题未更新、缺少分享前结构校验、历史文档中的本机绝对路径。

新增/强化：`validate-flowmaker.ps1`，校验流程 JSON、方向、节点 ID、节点类型、边引用和 dashed 字段。

验证：模板校验通过（6 个节点、5 条边）；PowerShell Parser 通过；相关 Node 脚本语法通过。

剩余风险：运行时依赖 esm.sh CDN；复杂回流和多分支仍受 dagre 布局能力限制；`detail` 支持 HTML，只应接收可信内容。

## prism

入口：`C:\Users\admin\.agents\skills\prism\SKILL.md`

已修复：远程 provider 和运行时覆盖地址强制 HTTPS；客户端错误不再把同一请求自动转发到备用 provider；默认不写出 raw_content；归档只允许脱敏摘要、指标和错误摘要。

验证：`panel.ps1`、`panel-worker.ps1`、`init-prism.ps1` Parser 通过；providers/models schema 校验通过；未发现真实 API key、Bearer token 或用户绝对路径。

剩余风险：使用者仍需自行审查 provider、API key 文件权限和供应商隐私条款；专家无独立搜索能力时，事实 Grounding 仍依赖主 Agent。

## wardrobe-stylist

入口：[skills/wardrobe-stylist/SKILL.md](skills/wardrobe-stylist/SKILL.md)

已修复：个人数据与 Skill 包耦合、无数据时误装作拥有衣橱、路径和服务校验不足、单品与照片边界不够明确、写入缺少用户同意、研究结果缺少来源/时间/离线降级、默认地域假设。

现在通过 `WARDROBE_URL` 或 `WARDROBE_DATA_DIR` 接入使用者自己的数据；服务或清单不可用时走 onboarding / 手动输入。照片、数据库、profile、token、cookie 均不得进入 Skill 包。

验证：包内仅有预期的 4 个文件；UTF-8、YAML 必要字段、个人路径和个人数据检查通过。

剩余风险：需要使用者配置自己的数据源，并在目标环境做一次真实服务 API、天气和购物研究的端到端冒烟测试。

## 发布前清单

- 打包时只包含 Skill 说明、references、agents 元数据和必要脚本/模板。
- 删除个人照片、数据库、profile、cookie、密钥和绝对路径。
- 用空数据目录安装一次，确认首次运行能正确引导。
- 在受限网络下验证流程图的 CDN 提示是否清楚。
- 用测试 provider 验证 Prism 的密钥、HTTPS、fallback 和归档行为。
- 用另一位使用者的数据目录验证衣橱 Skill 的单品、照片和写入边界。
