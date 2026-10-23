# core/09-difference-mining.md · Analyst 拆 Claim

## 你的任务
调 Analyst 拆 Claim，计算三指标分歧度。

## 组装 in.json（单请求）
```json
{
  "requests": [
    {
      "id": "analyst",
      "model": "gpt-5.4-mini",  // 或 gemini-3.1-pro-preview（避免和主 Agent 同源）
      "system_prompt": <prompts/analyst.md>,
      "user_prompt": <JSON.stringify({
        "expert_versions": session_state.expert_versions[current_round],
        "shared_facts": session_state.shared_facts,
        "output_schema": <claim_table schema>
      })>,
      "response_format": "json_schema",
      "schema": <claim_table schema>
    }
  ],
  "timeout_seconds": 60,
  "parallel": false
}
```

## 计算三指标
```python
D_conflict    = analyst_output.metrics.conflict_count / analyst_output.metrics.total_groups
D_uncertainty = count(claim.evidence_needed=True AND not verified) / count(claim.evidence_needed=True)
D_coverage    = analyst_output.metrics.gap_count / analyst_output.metrics.total_groups
```

首轮 D_uncertainty 通常等于 count(evidence_needed=True) / count(evidence_needed=True) = 1.0（还没做后置 Grounding），这是正常的，S10 循环里会降下来。

## 输出
- `session_state.claim_table`
- `session_state.convergence.D_conflict / D_uncertainty / D_coverage`

## 完成后
进入 **S10** cross-review-loop。

---
