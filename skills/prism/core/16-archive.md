# core/16-archive.md · Human Gate + 归档

## 你的任务
展示最终报告，触发 Human Gate（如果必要），归档到 outputs/。

## Human Gate 判定
```
require_gate = (
    depth == "deep"
    or metadata.reversibility == "irreversible"
    or "🔴 unresolved" in session_state.audit_notes
)
```

## 展示 + 确认
```
show(final_report.md)

if require_gate:
    AskUserQuestion({
      question: "这个报告是否作为最终决策依据？",
      options: [
        { label: "是 · 确认", description: "作为决策依据" },
        { label: "需要修改", description: "指出哪里需要改" },
        { label: "作为参考，我另有决策", description: "只作参考不算决策" }
      ]
    })
    存 user_decision 到归档 appendix
```

## 归档
```
if "--no-archive" not in flags:
    slug = slugify(clarified_question)[:60]
    date = date_only_from_shared_facts_or_arg(...)  # 不用系统时间，用契约里的时间
    filename = f"outputs/{date}-{slug}.md"

    archive_content = final_report.md + "\n\n---\n\n" + build_appendix(session_state)
    write(filename, archive_content)
```

## Appendix 结构
```markdown
## 归档 Appendix（内部数据 · 供复盘用）

### metadata
{全部 metadata 字段}

### 内部字段（未在报告展示）
- 完整 key_claims: {n} 条
- 每轮 D_conflict / D_uncertainty / D_int 变化：[...]
- claim_table: {全量}
- 每家专家每轮的独立方案: {...}
- audit_findings 完整清单: [...]

### 可复盘状态摘要
只归档用于复盘的脱敏元数据、指标、错误摘要和字段计数。不得把 `raw_question`、完整 `contract`、`shared_facts` 原文、专家 prompt/response、`raw_content` 或完整 `session_state` 写入归档；这些字段可能包含用户输入或供应商返回的敏感内容。若确需复盘，保存经用户确认的摘要或哈希，而不是原文。
```

## 完成后
```
汇报："✅ 流程结束。报告已归档到 {filename}"
End
```

## 不做的事
- ❌ 不用系统时间 API（Claude Code 里可能不可用）—— 用契约里的时间戳或用户在澄清阶段说的日期
- ❌ 不覆盖同名归档（若冲突，加 -2 后缀）
- ❌ 不归档到 skill 目录外（严格 outputs/ 子目录）
- ❌ 不在归档里出现真实 API key、用户敏感原文、完整 prompt/response 或 `raw_content`（软性代号化不等于安全脱敏）
