# core/11-integrator.md · 双 Integrator 调度

## 你的任务
S10 循环体的第 ⑤~⑦ 步：调双 Integrator 并行融合。

## 组装 in.json
```json
{
  "requests": [
    {
      "id": "integrator_I",
      "model": "gpt-5.4-mini",
      "system_prompt": <prompts/integrator-consensus.md>,
      "user_prompt": <JSON.stringify({
        "expert_revisions": session_state.expert_versions[round],
        "claim_table": session_state.claim_table,
        "shared_facts": session_state.shared_facts
      })>,
      "response_format": "json_schema",
      "schema": <schema-internal.json>
    },
    {
      "id": "integrator_II",
      "model": "gemini-3.1-pro-preview",
      "system_prompt": <prompts/integrator-divergence.md>,
      "user_prompt": <same as above>,
      "response_format": "json_schema",
      "schema": <schema-internal.json>
    }
  ],
  "timeout_seconds": 90,
  "parallel": true
}
```

## 处理结果
- 成功 → 存入 `session_state.integrated_versions[round]`
- 其中一个失败 → 用成功的那个继续，D_int 不计算（视为 0）
- 全部失败 → 用上一轮的 integrated 作为退化选项 + 报告标注

## standard 档
如果 depth == "standard"，只调 Integrator I（不用双 Integrator），D_int 强制为 0。

## 完成后
返回 S10 循环体继续第 ⑧ 步。

---
