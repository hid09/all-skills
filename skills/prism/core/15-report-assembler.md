# Prompt · 15 · Report Assembler（揭盲 + 章节按需拼装）

> **文件位置**：`~/.claude/skills/prism/core/15-report-assembler.md`
> **对应 workflow**：S15
> **输入**：`final_version` + `metadata.sections_to_include` + `alias_map` + `reverse_map` + `grounding_level` + `session_state` 全量
> **输出**：`final_report.md`（用户看到的报告）

---

## 你的任务

把系统内部产出（`final_version`、`claim_table`、`audit_findings`、`session_state`）**按 metadata 决定的章节组合**拼装成用户可读的 markdown 报告。

**关键**：这是 V4 通用版最核心的落地环节 —— 用户看到的永远是"综合分析报告"，章节根据问题自然变化，没有"这是 Research 报告"或"这是 Decision 报告"的区分。

## Step 1 · 揭盲：填 traceability 字段

```python
traceability = {
    "expert_a_actual": reverse_map["expert_A"],  # e.g. "GPT-5"
    "expert_b_actual": reverse_map["expert_B"],  # e.g. "Gemini"
    "expert_c_actual": reverse_map["expert_C"],  # e.g. "DeepSeek"
    "grounding_source": "主 Agent 单源（专家无搜索能力）",  # ⭐ 诚实标注（V4.1）
    "grounding_level": grounding_level,          # L0 | L1 | L2
    "convergence_status": session_state.convergence_status,
    "total_rounds": session_state.round,
    "human_gate_triggered": session_state.metadata.reversibility == "irreversible" or depth == "deep"
}
```

## Step 2 · 决定 dissenting_opinions 是否加入

Cross Review 退出时，如果 non_factual check 通过但仍有 value-based / preference-based 分歧 → 把 dissenting_opinions 加进 sections。

```python
if any(c.type == "conflict" and c.disagreement_tag in ("value-based", "preference-based")
       for c in claim_table):
    metadata.sections_to_include.append("dissenting_opinions")
```

## Step 3 · 判定 key_claims 是否展示

```python
if depth == "deep":
    metadata.sections_to_include.append("key_claims")
elif D_conflict > 0.05:  # standard 档也可能展示
    metadata.sections_to_include.append("key_claims")
```

## Step 4 · 报告顶部警示条（根据 grounding_level）

```python
if grounding_level == "L2":
    top_banner = """
🔴 未验证报告 · 仅供参考

WebSearch 完全不可用，本次未能对涉及事实的字段做验证。
请勿基于本报告做不可逆决策。

"""
elif grounding_level == "L1":
    top_banner = """
⚠️ 部分事实未验证

WebSearch 部分降级，报告中标 ⚠️ 的字段未通过验证，请人工核对。

"""
else:  # L0
    top_banner = ""
```

## Step 5 · 按 sections_to_include 拼装章节

**强制章节先拼**（顺序固定）：

```python
sections_order = [
    "problem_contract",   # 强制
    "verified_facts",     # 条件：fact_density >= medium
    "key_claims",         # 条件：deep 或 D_conflict > 0.05
    "candidate_solutions", # 条件：has_solution_component
    "trade_offs",         # 条件：has_tradeoff_component
    "recommendation",     # 强制
    "risks",              # 强制
    "assumptions",
    "dissenting_opinions",# 条件：value-based 分歧存在
    "next_steps",         # 条件：irreversible 或用户要求
    "traceability"        # 强制
]

report_md = top_banner + "\n# 分析报告\n\n"

for section in sections_order:
    if section in metadata.sections_to_include:
        template = read(f"templates/sections/{section}.md")
        rendered = render(template, {
            "final_version": final_version,
            "traceability": traceability,
            "claim_table": claim_table,
            "audit_findings": audit_findings,
            "session_state": session_state
        })
        report_md += rendered + "\n\n---\n\n"
```

## Step 6 · 处理章节内的字段级警示

在 rendering 阶段：

- Grounding 打 ✅ 的字段 → 后面加 ✓
- Grounding 打 ⚠️ 的字段 → 后面加 ⚠️
- Grounding 打 ❌ 的字段 → 后面加 ❌（已修正）或 ❌ (已排除)

## Step 7 · 附加 Final Audit 遗留问题

如果 mini review 后仍有 🔴 阻塞 → 在 recommendation 前插入警示块：

```markdown
## ⚠️ 需要您人工判断

Final Audit 发现的以下问题多 AI 无法自动解决：
- <blocker 1 描述>
- <blocker 2 描述>

请您在阅读推荐结论时，重点关注这些点。
```

## Step 8 · 附加"未展示但已产出"的字段提示

在 traceability 章节末尾：

```markdown
### 完整数据

本次协作产生了以下未展示的内部字段（可在归档文件的 appendix 查看）：
- 内部 key_claims: {n} 条
- 各专家的完整独立方案（含拒绝清单）
- 每轮 D_conflict / D_uncertainty / D_int 变化历史
- Analyst 拆 Claim 的完整对齐表

归档路径：{archive_path}（S16 生成）
```

## Step 9 · 汇报给用户

```
📄 报告已生成（章节：{sections list}）
⚙️ 揭盲：专家 A = <actual>，专家 B = <actual>，专家 C = <actual>
⚙️ Grounding 等级：{grounding_level}
⚙️ 循环状态：{convergence_status}（{rounds} 轮）

准备进入 S16 Human Gate + 归档...
```

## 完成后

设置 `session_state.final_report`，进入 **S16**：读取 `core/16-archive.md`。

## 不做的事

- ❌ 不在报告里出现 "mode / research / design / decide"
- ❌ 不隐瞒 grounding_source = 单源
- ❌ 不省略 traceability 章节（永远必含）
- ❌ 不强行合并 dissenting_opinions（少数意见的价值在于保留）
- ❌ 不在正文用"大概/也许/可能是"这种模糊词描述已验证的事实（Grounding 结果就是明确的 ✅/⚠️/❌）
- ❌ 不把"未展示"的字段完全丢弃（归档时全保留）
