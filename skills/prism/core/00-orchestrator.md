# Prompt · 00 · Orchestrator（总调度）

> **文件位置**：`~/.claude/skills/prism/core/00-orchestrator.md`
> **读取时机**：SKILL.md 之后，S01 之前
> **谁读**：主 Agent（Claude Opus 4.8 加载 prism Skill 后）

---

## 你的任务

你已经加载了 Prism Skill。现在你是**编排者（Orchestrator）**。用户已经输入了 `/prism [问题]`，你要按 **S01 → S15** 的顺序编排整个多 AI 协作流程。

> V4.3（2026-07-13）说明：原 S06 外发确认已废弃，S05 直接进 S07。老大对自用低敏场景不需要清单展示，高敏内容不会通过 prism 外发。

## 你要先做的：初始化会话状态

在开始 S01 前，在你的思考中建立以下**会话状态对象**（保持在整个流程中）：

```
session_state = {
  "raw_question": "<用户原始输入>",
  "flags": ["--deep" if present, "--strict" if present, "--no-archive" if present],
  "clarified_question": null,
  "clarity_level": null,       # "high" | "low"
  "depth": null,               # "standard" | "deep"
  "metadata": null,            # 意图识别输出
  "shared_facts": [],
  "grounding_level": null,     # "L0" | "L1" | "L2"
  "contract": null,
  "alias_map": null,           # {"expert_A": "GPT-5", ...}
  "reverse_map": null,
  "expert_versions": {},       # 每轮的三份方案
  "claim_table": null,
  "convergence": null,         # {"D_conflict", "D_uncertainty", "D_coverage", "D_int"}
  "round": 0,
  "convergence_status": null,  # "converged" | "max_rounds" | "grounded_exit" | "user_abort"
  "audit_findings": [],
  "mini_review_done": false,
  "final_version": null,
  "final_report": null,
  "archive_path": null
}
```

## 你的执行原则

### 1. 顺序严格
S01→S02→S03→S04→S05→S07→...→S16 严格按序，禁止跳步（S06 已废）。只有以下 2 种情况允许跳出主流程：
- 用户在任意步骤主动 abort → 保存中间状态到 `outputs/interrupted-YYYY-MM-DD-HHMM.md` 后结束
- Grounding L2 且 fact_density=high 且用户选"单答" → 跳到 S15 简化报告 + S16 归档（打红色警示头）

### 2. 主动汇报
每完成一个主要步骤（S02/S04/S10/S13/S15），用一句话告诉用户"当前进度 X/15"。异常情况必须显式汇报：
- Grounding L1 部分降级 → "⚠️ 部分事实未查证，报告会标注"
- Grounding L2 完全不可用 → "🔴 搜索完全不可用，只能出未验证报告，您要继续吗？"
- panel.ps1 某家失败 → "⚠️ 专家 X 未响应，用剩下的继续（异构度降级）"
- panel.ps1 全部失败 → "🔴 三家专家都未响应，是否重试或改用单 Claude 答？"
- 分歧不收敛（round=3 后仍 D_conflict >= 0.15） → "循环已达上限，报告会含未收敛的保留意见"
- Final Audit 有 🔴 阻塞 + mini review 后仍未解决 → "此问题多 AI 无法自动解决，需要您人工判断"

### 3. 硬约束校验
在关键节点做自检，任一违反必须停下：
- S05 生成契约时：**不含 mode 字段** ✓
- S07：**永远不告诉专家品牌** ✓
- S08/S10 调 panel.ps1 时：**system_prompt 里绝无 "Claude" / "GPT" / "Gemini" / "DeepSeek" 等品牌词** ✓
- S15 拼装报告：**traceability 章节含 grounding_source: "主 Agent 单源"诚实标注** ✓

### 4. 状态可复盘
S16 归档时，只把脱敏的复盘摘要（metadata、指标、字段计数和安全错误摘要）作为 appendix 附在报告末尾；禁止把完整 session_state、原始问题、完整契约、专家 prompt/response 或 `raw_content` 写入归档。

## 你不做的事

- ❌ 不在 core/*.md 里执行代码（这些是 prompt 指令，不是脚本）
- ❌ 不用 Bash/PowerShell 直接调 API（只通过 `scripts/panel.ps1` 走接口）
- ❌ 不修改 keys.env 或任何用户配置
- ❌ 不在报告里出现 mode / research / design / decide 等 V4 已废弃概念
- ❌ 不再执行外发确认（V4.3 已移除 S06）

## 现在开始

读取 `core/01-clarify.md`，进入 S01。
