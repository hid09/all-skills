# core/14-mini-review.md · 问题回补 + Standard 轻审计（V4.2）

## 你的任务

本文件覆盖两个场景：

1. deep 档：沿用 V4.1 的 Final Audit 后问题回补。
2. standard 档：执行固定结构 **2 experts + 1 integrator + 1 mini-auditor**。

---

## A. Deep 档问题回补（沿用 V4.1）

按 Final Audit 结果做分级处理：

```
blockers = [f for f in audit_findings if f.severity == "🔴"]
severe = [f for f in audit_findings if f.severity == "🟠"]
warnings = [f for f in audit_findings if f.severity == "🟡"]
suggestions = [f for f in audit_findings if f.severity == "🟢"]

if blockers:
    if not session_state.mini_review_done:
        mini_prompt = f"以下是审计发现的阻塞问题：{blockers}. 请针对性修订你的方案。"
        for expert_id in ["expert_A", "expert_B", "expert_C"]:
            requests.append({...mini_prompt...})
        result = call_panel(requests)
        session_state.final_version = merge(session_state.last_integrated_version, result)
        session_state.mini_review_done = True
        goto S13
    else:
        raise HumanGateRequired(reason="阻塞问题多 AI 无法自动解决", blockers=blockers)

for f in severe:
    session_state.final_version.risks.append({
        "risk": f.description,
        "source": "final_audit",
        "severity": "high"
    })

session_state.audit_notes["warnings"] = warnings
session_state.audit_notes["suggestions"] = suggestions
```

---

## B. Standard 档轻审计（HC-14 / HC-15）

当 `session_state.depth == "standard"` 时，不跑 deep 档三审计员，也不跑 Cross Review 循环。standard 固定结构：

```
2 experts + 1 integrator + 1 mini-auditor
```

### Step 1 · 两位专家独立输出

从 `models.json.pools.standard_pool` 按 `core/02-router.md` 的池选算法挑 2 家。

### Step 2 · 单 Integrator 融合

使用 `prompts/integrator-consensus.md`，从 `deep_pool` 或可用 provider 中挑 1 家作为 Integrator。主 Agent 不亲自融合，以避免 Claude 主 Agent 污染 worker 输出。

### Step 3 · Mini-Auditor 三合一轻审计

调用：

- prompt：`prompts/mini-auditor-combined.md`
- schema：`templates/schema-mini-audit.json`
- response_format：优先 `json_schema`，不支持时降级 `json_object`

输入：

```
{
  "integrated_version": session_state.last_integrated_version,
  "contract": session_state.contract,
  "grounding_level": session_state.grounding_level
}
```

输出必须符合：

```json
{
  "consensus": ["..."],
  "fact_check": [
    {"claim": "...", "evidence_needed": "...", "priority": "high"}
  ],
  "risks": [
    {"risk": "...", "severity": "medium", "mitigation": "..."}
  ]
}
```

### enum 硬约束

- `priority`: 只能是 `high` / `medium` / `low`
- `severity`: 只能是 `high` / `medium` / `low`
- 禁止任何不在上述三值内的自由值、大小写变体或语言变体

### 校验失败处理

1. mini-auditor 输出不符合 `schema-mini-audit.json` → 重试 1 次。
2. 重试仍失败 → 标记 `status = "invalid_response"`，报告中说明轻审计不可用。
3. 不因 mini-auditor 失败而丢弃专家和 Integrator 的结果。

## 输出

- deep：`session_state.final_version` + `session_state.audit_notes`
- standard：`session_state.mini_audit` + 合并进最终报告的 consensus / fact_check / risks 三段

## 完成后

进入 **S15** report-assembler。
