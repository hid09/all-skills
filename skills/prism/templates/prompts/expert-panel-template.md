# 通用专家 prompt 模板 · 强制含填好的 JSON 示例

> **文件位置**：`~/.claude/skills/prism/templates/prompts/expert-panel-template.md`
> **谁用**：主 Agent 在 S08 独立推理拼装 in.json 时套这个模板
> **为什么存在**：光模块调研任务时,主 Agent 现编 prompt 三家全崩(一家自编字段/一家吐 schema 元数据/一家 400),用模板可避免

---

## 主 Agent 使用说明

### 1. 什么时候用

S08 首轮独立推理、S10 Cross Review 修订 · 每一次调 panel.ps1 让专家产出结构化 JSON 时都套本模板。

### 2. 模板结构 · 4 段固定

```
【调研问题】...
【用户背景】...
【已核实的共享事实(shared_facts)】...
【你的任务 · 角度: XXX】...

【严格按下方 JSON 结构输出】(填入真实分析,不要照抄示例内容)
{ ...填好的示例... }

【重点关注】
1. ...
2. ...

只输出 json,不要 markdown 围栏,不要品牌名。
```

### 3. 关键红线(违反必踩坑)

| 红线 | 后果 | 修法 |
|---|---|---|
| **JSON 示例必须是"填好的具体内容"** · 不是 schema 元数据 | Gemini 家会把示例的 `properties`/`type`/`description` 当成让它生成 schema | 每字段给真实占位内容("你的核心主张 1, 50-150 字") |
| **禁止只说"按 xxx schema 输出"** · 必须列字段 | GPT/Gemini 都会自编字段名 | 直接把 JSON 骨架贴在 prompt 里 |
| **messages 必须含小写 `json` 字样** | OpenAI 兼容规范 · tokenopen/deepseek 稳定 HTTP 400 | 本模板里"输出 json"/"json 格式"已内建 |
| **禁止提及品牌名**(GPT/Claude/Gemini/DeepSeek) | 违反匿名硬约束 | system_prompt 明说"禁止提及" |
| **dissenting_note 必须有 · ≥50 字** | 少数意见是 prism 核心价值 | prompt 里明说"必须有 · 不许偷懒" |

### 4. 模板本体(可直接复制到主 Agent 拼装逻辑)

#### system_prompt 模板

```
你是资深{领域}分析师(代号:专家{A/B/C})。你不知道其他专家的身份,他们也不知道你的。禁止在输出中提及 GPT、Claude、Gemini、DeepSeek 等品牌名。你的分析角度是:{lens 组合}。用中文输出 json 对象,严格按下方示例的字段结构。
```

#### user_prompt 模板

```
【调研问题】{clarified_question}

【用户背景】{用户提供的背景说明 · 从 S01 澄清结果拼出}

【已核实的共享事实(shared_facts, 主 Agent 单源前置 Grounding {L0|L1|L2})】

F001: {事实 1 · 一段话}

F002: {事实 2}

...

【你的任务】
作为专家 {A/B/C}, 从'{lens 描述}'角度输出深度分析。

【严格按下方 JSON 结构输出】(填入你的真实分析,别照抄示例内容)

{
  "depth": "{standard|deep}",
  "question_summary": "一句话总结用户问的什么",
  "shared_facts_reference": ["F001", "F003"],
  "key_claims": [
    {
      "claim_id": "C001",
      "claim": "你的核心主张 1, 50-150 字",
      "type": "consensus",
      "evidence_needed": true,
      "confidence": "high",
      "source_expert": "{A|B|C}"
    }
  ],
  "recommendation": {
    "primary": "你的核心结论, 200-400 字",
    "conditions": "在什么前提下这个结论成立",
    "confidence": "medium"
  },
  "assumptions": ["核心假设 1", "核心假设 2"],
  "risks": [
    {"risk": "风险描述", "severity": "high", "mitigation": "缓解措施", "source": "expert_{A|B|C}"}
  ],
  "dissenting_note": "如果我错了, 可能错在哪 —— 至少 50 字, 必须有反思",
  "confidence_summary": {"overall": "medium"},
  "traceability": {
    "grounding_source": "主 Agent 单源(专家无搜索能力)",
    "grounding_level": "{L0|L1|L2}"
  },
  "human_gate_required": false
}

【重点关注】
1. {场景重点 1}
2. {场景重点 2}
3. {场景重点 3}
4. dissenting_note 必须有,别偷懒说"没有反思"

只输出 json,不要 markdown 围栏,不要品牌名。
```

### 5. 三家 lens 配置建议

standard 档 2 家:

| 专家 | lens |
|---|---|
| A | solution + tradeoff |
| B | facts + boundary |

deep 档 3 家:

| 专家 | lens |
|---|---|
| A | solution + tradeoff(方案设计 + 权衡取舍) |
| B | facts(事实核验 + 数据严格性) |
| C | boundary + risk(边界质疑 + 投资/风险逻辑) |

### 6. 参数建议

| 参数 | 值 | 理由 |
|---|---|---|
| `response_format` | `json_object` | strict json_schema tokenopen 部分模型不支持 |
| `max_tokens` | 20000(reasoning 模型) / 12000(standard 模型) | reasoning 需要给思考链留空间 |
| `temperature` | A=0.7 / B=0.5 / C=0.6 | B 严格用低温度 |
| `parallel` | true | 3 家并行(panel.ps1 会顺序 fallback) |

### 7. 常见错误 · 出问题时先查

| 症状 | 检查 |
|---|---|
| 专家输出字段全乱 · 自编 investment_thesis 等 | prompt 里是否给了填好的 JSON 示例(不是 schema) |
| 专家吐 `$schema`/`properties`/`type` | prompt 里是否提到"按 schema" · 改成"按下方 JSON 结构" |
| deepseek 家 HTTP 400 空 body | prompt 里是否有 `·` 中间点(U+00B7) · panel.ps1 已自动 sanitize |
| gpt 家 HTTP 400 "must contain the word json" | messages 是否含小写 `json` · panel.ps1 已自动追加 |
| gpt-5.4-mini 供应商侧 503 | 走 backup(out.json 的 `backup_used=true`) · 无解 |
| dissenting_note 空或极短 | prompt 里必须显式"至少 50 字" |

### 8. 关联记忆

- [[deepseek-middle-dot-400]] · deepseek `·` 400 bug
- [[prism-gemini-max-tokens]] · reasoning 模型 max_tokens 陷阱
- [[three-stage-collab-mode]] · 三阶段协作模式
