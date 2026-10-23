# core/05-contract-builder.md · 契约生成

## 你的任务
把 clarified_question + shared_facts + metadata 组装成给专家的契约。

## 契约模板（严格遵守）

```json
{
  "depth": "standard | deep",
  "question": "<clarified_question 完整版>",
  "context": {
    "现状": "<从 clarified_question 提取>",
    "问题": "<从 clarified_question 提取>",
    "目标": "<从 clarified_question 提取>",
    "约束": "<从 clarified_question 提取>",
    "时间": "<从 clarified_question 提取>"
  },
  "shared_facts": [<S04 输出>],
  "output_requirements": {
    "claims_required": true,
    "evidence_needed_marking": true,
    "risks_required": true,
    "assumptions_required": true,
    "dissenting_note_required": true
  },
  "output_schema": {<引用 templates/schema-internal.json>},
  "evaluation_criteria": [
    "结构化程度：claims 清晰列出",
    "证据标记：涉及事实的字段标 evidence_needed",
    "独立性：不合流其他专家",
    "反思：dissenting_note 有内容"
  ]
}
```

## ⚠️ 关键约束
- **不含 mode 字段**（V4 已删）
- **不含 metadata**（那是内部的）
- **不含真实人名/公司名/项目名**（用软性代号化后的版本）

## 软性代号化（V4.1 数据处理边界）
在契约构建阶段，对真实人名 / 公司名 / 项目名做代号替换：
- 张三 → 候选人 A
- 阿里巴巴 → 组织 X
- 某未公开项目 → 项目 P

保留代号映射表在 session_state.entity_map（S15 揭盲时用）。

## deep 档契约 Review
如果 depth == "deep"：
- 展示 contract 给用户
- `AskUserQuestion("契约看起来对吗？")`
- 用户修改 → 回本步骤重新组装

## 输出
`session_state.contract`

## 完成后
进入 **S07** anonymizer（V4.3 已废除 S06 外发确认）。

---
