# Troubleshoot · 故障排查 SOP

> **文件位置**：`~/.claude/skills/prism/core/99-troubleshoot.md`
> **触发时机**:panel.ps1 结果异常时(HTTP 4xx/5xx/超时/空返回/输出结构不对/JSON parse 失败)
> **原则**:先抓证据,再下结论。禁止拍脑袋改配置。

---

## 5 步定位法

### Step 1 · 抓 error body

**先看 out.json 的 error 字段和 raw_content**。若 error 是"HTTP 400 call failed"这种笼统提示 · 需要**直连 provider 抓 400 的实际响应 body**。

```powershell
# 复现失败请求 · 加入 stream reader 抓 body
try {
    $resp = Invoke-WebRequest -Method Post -Uri $uri -Headers $h -Body $body -TimeoutSec 60 -UseBasicParsing
} catch {
    $status = [int]$_.Exception.Response.StatusCode
    $stream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $errBody = $reader.ReadToEnd()
    Write-Host "status=$status body=$errBody"
}
```

**注意**:deepseek 官方 400 有时 body 为空 · gpt 家一般有 JSON error message。

---

### Step 2 · 二分 prompt

若 error body 没写清楚原因 · 说明是**内容触发**问题(某字符/某关键词)。二分 user_prompt 定位。

```
半段测试:
  half1 = prompt[0 : len/2]
  half2 = prompt[len/2 : ]

哪半 400 就继续二分那半 · 直到定位到 1-2 行触发字符
```

**已知触发字符**(已加 memory):

| 字符 | 触发 provider | 现象 | 修法 |
|---|---|---|---|
| `·` (U+00B7 中间点) | deepseek | HTTP 400 空 body | panel.ps1 已自动 sanitize → `,` |
| 无小写 `json` 字样 | tokenopen 家 gpt / deepseek 官方(response_format=json_object 时) | HTTP 400 "must contain the word json" | panel.ps1 已自动追加 |

---

### Step 3 · 边界测参数

若 error 说"max_tokens"/"temperature"/"context" 相关 · 别单点验证 · **要用 3 点二分**:

```
❌ 错的:测一次 16000 通过就下结论"上限 16000"
✅ 对的:测 20000/32000/64000/128000 · 找到真实边界
```

**已知 provider 参数上限**(2026-07-11):

| provider | model | max_tokens 上限 | context 上限 |
|---|---|---|---|
| deepseek 官方 | deepseek-v4-pro | **384k**(官方文档) | 1M |
| tokenopen | gpt-5.5 | 8k(推测) | 128k |
| tokenopen | gemini-3.1-pro-preview | 32k(推测) | 1M |

⚠️ 未验证的写"推测" · 别当事实用。**改配置前必查官方文档**(URL 记 refs/provider-limits.md)。

---

### Step 4 · 查官方文档

**在拍脑袋改代码前必查**。**没查过就说"上限是 X"是不专业**。

**关键文档**:
- DeepSeek: https://api-docs.deepseek.com/zh-cn/quick_start/pricing/
- OpenAI: https://platform.openai.com/docs/api-reference
- Anthropic: https://docs.anthropic.com/en/api
- Google: https://ai.google.dev/api/rest

**没找到官方文档**:说明这是**中转商私有规则** · 只能通过实测二分定位 · 修完后**记 memory**。

---

### Step 5 · 记 memory 防复发

修完后**必须**记一条 memory · 格式:

```markdown
---
name: <slug>
description: 一句话
metadata:
  type: reference
---

**现象**:...
**根因**:...
**验证**:...
**修法**:...
**关联**:[[其他相关 memory]]
```

**已有故障 memory**:
- [[deepseek-middle-dot-400]]
- [[prism-gemini-max-tokens]]
- [[prism-key-check-order]]

---

## 常见故障速查表

| 症状 | 首查 | 常见根因 |
|---|---|---|
| out.json 全体 backup_used=true 且 requested_model 相同 | tokenopen/deepseek 某个上游挂了 | 供应商侧 · backup 兜住 · 汇报给用户 |
| HTTP 503 | Step 1 抓 body | 供应商侧短时故障 · 等或换 provider |
| HTTP 400 空 body(deepseek) | Step 2 二分 prompt | 通常是 `·` 中间点 · panel.ps1 已 sanitize |
| HTTP 400 "must contain the word json" | Step 1 | prompt 无小写 json 字样 · panel.ps1 已 auto-append |
| HTTP 400 其他内容 | Step 1+2+4 | 内容触发 · 参数越界 · 或格式问题 |
| 超时 | Step 3 边界测 timeout · 4 查文档 | provider 处理慢 · 长 prompt · 复杂 reasoning |
| content 为空但 status=success | 看 tokens_used 里 reasoning_tokens | max_tokens 太小被思考链吃光 · reasoning 模型给 ≥16000 |
| content 是 schema 元数据不是内容 | 看 prompt | 说了"按 schema" · 改用 "按下方 JSON 结构" · 给填好的示例 |
| content 字段全乱自编名 | 看 prompt | 没给具体字段清单 · 用 templates/prompts/expert-panel-template.md |

---

## 主 Agent 汇报规范

排查过程要**主动汇报**给用户 · 不要闷头改代码:

```
⚠️ 专家 X 返回异常 · 错误:HTTP 400
🔍 抓到错误 body:...
🔍 二分定位到触发字符/参数:...
✅ 已修:...
📝 已记 memory:...
```

**禁止**:
- ❌ 拍脑袋改 max_tokens/temperature/prompt 不解释理由
- ❌ 只测一个通过就下结论"上限是 X"
- ❌ 说"应该是 XX 问题"但不抓证据
- ❌ 修完不记 memory 让后人再踩

---

## 特殊情况

### 全部专家挂(3/3 failed)

**S00 orchestrator 汇报**:
```
🔴 三家专家全部未响应 · 是否重试或改用单 Claude 答?
[Y-重试]  [N-单 Claude]  [S-终止]
```

### backup_pool 也挂

out.json 里 `failed_attempts` 会列出所有尝试过的 model 及各自 error · 主 Agent 汇报:

```
🔴 主 model {X} 失败({err1}) · backup {Y} 也失败({err2}) · 建议改 provider 或补 backup 模型
```

### response_format_downgraded=true

某家专家的 json_schema 不被 provider 支持 · panel.ps1 自动降级到 json_object · 主 Agent **必须汇报**:

```
⚠️ 专家 X 的 json_schema 不被 provider 支持 · 已降级到 json_object · 建议 review 输出结构
```

---

## 关联

- [[deepseek-middle-dot-400]] · deepseek U+00B7 400
- [[prism-gemini-max-tokens]] · reasoning 模型 max_tokens 陷阱
- [[prism-key-check-order]] · 密钥三层排查
- `templates/prompts/expert-panel-template.md` · 专家 prompt 模板
