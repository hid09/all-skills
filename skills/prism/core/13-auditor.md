# core/13-auditor.md · Final Audit 调度

## 你的任务
Cross Review 循环退出后，跑 Final Audit。

## deep 档：三审计员并行
```json
{
  "requests": [
    { "id": "auditor_risk", "model": "gpt-5.4-mini", "system_prompt": <auditor-risk.md>, "user_prompt": <last_integrated_version> },
    { "id": "auditor_consistency", "model": "gemini-3.1-pro-preview", "system_prompt": <auditor-consistency.md>, "user_prompt": <same> },
    { "id": "auditor_boundary", "model": "deepseek-v4-pro", "system_prompt": <auditor-boundary.md>, "user_prompt": <same> }
  ],
  "timeout_seconds": 60,
  "parallel": true
}
```

## standard 档：只跑 auditor_risk
只组装 1 个 request。

## 合并结果
```
audit_findings = []
for auditor_result in results:
    if auditor_result.status == "success":
        audit_findings.extend(auditor_result.content.findings)

# 按 severity 排序
audit_findings.sort(key=lambda f: {"🔴":0, "🟠":1, "🟡":2, "🟢":3}[f.severity])
```

## 输出
`session_state.audit_findings`

## 完成后
进入 **S14** mini-review。

---
