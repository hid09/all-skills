# Prompt · 03 · Intent Detector（意图识别）

> **文件位置**：`~/.claude/skills/prism/core/03-intent-detector.md`
> **对应 workflow**：S03
> **输入**：`clarified_question` + `depth`
> **输出**：`metadata`（内部对象，**不进契约、不给专家看、不进报告**）

---

## 你的任务

生成一份内部意图 metadata，用于**调参**：决定 Grounding 强度、决定专家 lens 组合、决定报告章节。

**关键约束**：这是内部参数选择器，不是"模式"。不给用户看，不出现在报告标题里，不写进契约。

## metadata schema

```json
{
  "fact_density": "low | medium | high",
  "has_solution_component": true | false,
  "has_tradeoff_component": true | false,
  "reversibility": "reversible | irreversible",
  "sections_to_include": [<section names>]
}
```

## 字段判定启发式

### fact_density

问题里"事实待验证"的密度。

| 值 | 触发条件（示例） |
|---|---|
| `high` | 涉及"最新数据 / 官方政策 / 具体金额 / 时效性强 / benchmark / 版本号 / 数据统计" |
| `medium` | 涉及少量事实核查（"某公司现状"、"某工具能力"），但主要是判断问题 |
| `low` | 纯理念 / 方案设计 / 价值取舍，几乎不涉及外部事实 |

### has_solution_component

问题里是否要产出"方案"或"如何做"的成分。

- **true**：问题里出现"怎么做 / 方案 / 架构 / 设计 / 实现路径 / 步骤"
- **false**：问题只求"要不要做 / 值不值 / 对不对"，不需要设计方案

### has_tradeoff_component

问题里是否有明显的取舍或对比。

- **true**：问题里出现"A 还是 B / 对比 / 取舍 / vs / 二选一 / 优劣"
- **false**：问题是单目标判断，无明显选项对立

### reversibility

决策后是否容易撤回。

| 值 | 触发条件 |
|---|---|
| `irreversible` | 涉及"签约 / 买房 / 换工作 / 婚姻 / 大额支出 / 一次性投入 / 时间窗口关闭" |
| `reversible` | 可以随时调整、试错成本低 |

### sections_to_include（自动生成）

按以下规则填：

```
sections = ["problem_contract", "recommendation", "risks", "traceability"]  # 强制

if fact_density in ("medium", "high"):
    sections.append("verified_facts")

if has_solution_component:
    sections.append("candidate_solutions")

if has_tradeoff_component:
    sections.append("trade_offs")

if reversibility == "irreversible":
    sections.append("next_steps")

if depth == "deep":
    sections.append("key_claims")  # deep 档默认展示 key_claims；standard 由 S10 D_conflict 决定

# assumptions 常规启用
sections.append("assumptions")

# dissenting_opinions 交给 S15 判定（value-based 分歧存在才加）
```

## 判定示例

### 示例 1
- **原始问题**："帮我看下 Rust 和 Go 哪个适合做我们的下一个后端服务"
- **metadata**:
  ```json
  {
    "fact_density": "medium",
    "has_solution_component": true,
    "has_tradeoff_component": true,
    "reversibility": "reversible",
    "sections_to_include": ["problem_contract", "recommendation", "risks", "traceability",
                            "verified_facts", "candidate_solutions", "trade_offs", "assumptions", "key_claims"]
  }
  ```

### 示例 2
- **原始问题**："这个合作对象靠谱不"
- **metadata**:
  ```json
  {
    "fact_density": "high",
    "has_solution_component": false,
    "has_tradeoff_component": false,
    "reversibility": "irreversible",
    "sections_to_include": ["problem_contract", "recommendation", "risks", "traceability",
                            "verified_facts", "next_steps", "assumptions"]
  }
  ```

### 示例 3
- **原始问题**："帮我梳理 DeFi 借贷协议的清算逻辑"
- **metadata**:
  ```json
  {
    "fact_density": "high",
    "has_solution_component": false,
    "has_tradeoff_component": false,
    "reversibility": "reversible",
    "sections_to_include": ["problem_contract", "recommendation", "risks", "traceability",
                            "verified_facts", "assumptions"]
  }
  ```

## 汇报（简短一句给用户）

```
"🔍 我看这题主要是 <fact_density-> <has_solution?"方案设计"><has_tradeoff?"权衡取舍"><irreversible?"不可逆决策">，
下一步会去搜 <search_count> 条事实基础。"
```

如："这题主要是权衡取舍 + 不可逆决策，下一步去搜 3 条事实基础。"

## 完成后

设置 `session_state.metadata`，进入 **S04**：读取 `core/04-grounding-pre.md`。

## 不做的事

- ❌ **不做 40%/60% 这种伪精确占比**（V4 明确删除）
- ❌ metadata **不写进契约**（专家看不到）
- ❌ metadata **不出现在最终报告里**
- ❌ 不基于 metadata 就替用户做决策（这是调参，不是判决）
