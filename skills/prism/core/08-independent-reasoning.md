# core/08-independent-reasoning.md · 首轮独立推理

## 你的任务
组装三份独立的专家 prompt,通过 panel.ps1 并行调用。

## ⭐ 使用通用模板(V4.2.1 新增 · 防止专家输出翻车)

**必须**用 `templates/prompts/expert-panel-template.md` 拼装 in.json 里的 system_prompt + user_prompt。该模板强制:

- prompt 里给填好的 JSON 示例(不是 schema 元数据)
- messages 含小写 `json` 字样(panel.ps1 会检测缺失并自动追加,但主动写更稳)
- 禁止品牌名 · 强制 dissenting_note ≥ 50 字

若跳过模板直接现编 prompt · 大概率遇到:专家自编字段 / Gemini 吐 schema 元数据 / 部分供应商 HTTP 400。

## 组装 in.json
```json
{
  "requests": [
    {
      "id": "expert_A",
      "model": <lookup(alias_map["expert_A"])>,  // 如 "gpt-5.4-mini"
      "system_prompt": <expert-panel-template 拼接的 system_prompt>,
      "user_prompt": <expert-panel-template 拼接的 user_prompt · 含填好的 JSON 示例>,
      "response_format": "json_object",  // V4.2.1 建议默认 json_object,strict json_schema 部分供应商不支持
      "max_tokens": 20000,               // reasoning 模型需要 ≥16000 · 见 [[prism-gemini-max-tokens]]
      "temperature": 0.7
    },
    { "id": "expert_B", ... },
    { "id": "expert_C", ... }
  ],
  "timeout_seconds": 180,
  "parallel": true
}
```

## Lens 拼接规则(送入模板的"任务 · 角度")
```
lenses = []
if metadata.fact_density in ("medium", "high"):
    lenses.append("prompts/expert-lens-facts.md")
if metadata.has_solution_component:
    lenses.append("prompts/expert-lens-solution.md")
if metadata.has_tradeoff_component:
    lenses.append("prompts/expert-lens-tradeoff.md")

# 主 Agent 把 lenses 描述作为"角度"参数传给 expert-panel-template
```

## 执行 · 进度可见(V4.2.1 新增)

```
write("tmp/in.json", in_json)
write("tmp/progress.json", initial_snapshot)  # 可选 · 主 Agent 后台可 poll

# ⭐ 汇报预计时长
tell_user("🔍 3 家专家开始独立推理 · 预计 60-180 秒(deep 档)")

# ⭐ 加 -ProgressFile 参数让 panel 边跑边写进度
call: powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/panel.ps1 -RequestFile tmp/in.json -OutputFile tmp/out.json -ProgressFile tmp/progress.json

read("tmp/out.json") → results
```

**用户等 >60 秒的场景**:主 Agent 可后台 poll `tmp/progress.json` 每 30 秒汇报 "已完成 X/3 家" · 别让用户干等。

## 处理结果 · V4.2.1 新字段

每份 result 都有:

| 字段 | 含义 |
|---|---|
| `status` | success / failed / timeout / invalid_response |
| `requested_model` | 主 Agent 原本请求的 model |
| `model` | **实际用的** model(可能是 backup) |
| `backup_used` | true 表示走了 backup_pool |
| `failed_attempts[]` | 每一次尝试失败的 model + error |
| `response_format_downgraded` | true 表示 json_schema 降级 json_object |

### ⭐ backup 汇报(V4.2.1 强制)

**若任一专家 `backup_used=true` · 必须汇报**:

```
⚠️ 专家 X 的首选模型 {requested_model} 未响应({failed_attempts[0].error})
   · 已自动切换到 backup {model} · 继续
```

若 `response_format_downgraded=true`:
```
⚠️ 专家 X 的 json_schema 不被 provider 支持 · 已降级 json_object · 建议 review 输出结构
```

## 分支处理

- 成功的家 → 存入 `session_state.expert_versions[0]`
- 失败的家(status=failed) → 标记"异构度不足",用剩下的继续
- 全部失败 → 汇报 + 询问用户"是否重试 / 改用单答"
- 输出字段全乱(不符合预期结构)→ 打开 [[expert-panel-template]] 检查是否真的用了填好的 JSON 示例 → 修 prompt 重跑
- 遇到 HTTP 4xx/5xx 反复失败 → 打开 `core/99-troubleshoot.md` 走 5 步定位法

## 完成后
进入 **S09** difference-mining。

---
