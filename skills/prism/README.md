# Prism

Prism 是一个 Claude Code Skill，用于通用多 AI 协作分析：复杂调研、方案设计、技术/商业/个人决策，以及这些问题的混合形态。

## V4.2 通用模型池

V4.2 把 provider 从 `panel.ps1` 代码里搬到配置文件：

- 出厂 provider：`config/providers.json`
- 用户 provider 覆盖：`~/.prism/providers.json`
- 出厂模型池：`config/models.json`
- 用户模型池覆盖：`~/.prism/models.local.json`

新增 provider 不再需要改 PowerShell 源码，只要增加 openai-compatible provider 配置。

首次使用建议运行：

```powershell
pwsh ~/.claude/skills/prism/scripts/init-prism.ps1
```

## 命令入口

```text
/prism [问题]
/prism [问题] --deep
/prism [问题] --strict
/prism [问题] --no-archive
/prism [问题] --standard
```

不支持 quick 档，不支持 mode 分流，不支持 lite 档。Prism 只区分 `standard` 和 `deep` 两档。V4.2 中 `/prism` 默认走 deep，`--standard` 才走 standard。

## 能做什么

- 多角度分析，发现单模型容易漏掉的盲区
- 让少数意见有地方被保留，而不是被硬合并
- 通过 claim table、Grounding、Final Audit 和归档 appendix 保持可追溯

## 不能做什么

- 不能替代用户的直觉、行业手感和最终判断
- 不能保证结论正确
- 不适合强时效、几秒内要答案的问题
- 不是真正多源 Grounding：专家没有搜索能力，Grounding 来源是主 Agent 单源

## 数据处理边界

Prism 会在契约生成阶段对真实人名、公司名、项目名做软性代号化，专家看到的是“候选人 A / 组织 X / 项目 P”一类代号。揭盲只发生在报告 traceability 层。

Prism 不提供完整 DLP 级脱敏，不做供应商合规审计，也不承诺专家请求字段级打码。外部请求会经过配置的 provider endpoint；不要把不想让供应商看到的内容交给 Prism。归档只保留脱敏摘要、指标和错误摘要，不写入原始问题、完整契约、专家 prompt/response 或 `raw_content`。

## Grounding 标注

报告的 traceability 必须写明：`grounding_source: 主 Agent 单源（专家无搜索能力）`。L1/L2 降级时，报告顶部必须分别显示黄色或红色警示。

## 文件结构

- `core/`：S01 到 S16 主流程指令
- `prompts/`：发给外部专家、Analyst、Integrator、Auditor 的 prompt
- `templates/`：JSON schema 与报告章节模板
- `scripts/`：`panel.ps1` 和辅助脚本
- `config/`：模型映射、敏感词、收敛阈值
- `examples/`：典型使用问题

`panel.ps1` 默认不把模型原始响应写入 `out.json`，避免调试产物意外携带用户内容。仅在本机短期排障、确认文件不会分享时显式加 `-IncludeRawContent`；归档流程禁止依赖该字段。
