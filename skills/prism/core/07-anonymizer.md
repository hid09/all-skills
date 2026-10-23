# core/07-anonymizer.md · 匿名映射

## 你的任务
分配代号，管理 alias_map 和 reverse_map。

## 默认模式（会话内稳定）
```
alias_map = {
  "expert_A": "GPT-5",
  "expert_B": "Gemini",
  "expert_C": "DeepSeek"
}
reverse_map = {v: k for k, v in alias_map.items()}
```
整个会话不变。

## 严格模式（--strict）
每次进入 S08 或 S10 循环体第 ② 步时：
```
import random
mapping = ["GPT-5", "Gemini", "DeepSeek"]
random.shuffle(mapping)
alias_map = {
  "expert_A": mapping[0],
  "expert_B": mapping[1],
  "expert_C": mapping[2]
}
```

同时在 in.json 的 system_prompt 里加一句：
> "以下代号是本轮临时分配，与上一轮无关。不要引用'上一轮的专家 X'。"

## 硬约束
- ❌ 永远不告诉专家品牌
- ❌ system_prompt 里绝无 "GPT" / "Gemini" / "DeepSeek" / "Claude"
- ✅ 只在 S15 揭盲阶段用于 traceability

## 输出
- `session_state.alias_map`
- `session_state.reverse_map`

## 完成后
进入 **S08** independent-reasoning。

---
