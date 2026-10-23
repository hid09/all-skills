# Prompt · 01 · Clarify（澄清需求）

> **文件位置**：`~/.claude/skills/prism/core/01-clarify.md`
> **对应 workflow**：S01
> **输入**：`raw_question` + `flags`
> **输出**：`clarified_question` + `clarity_level`

---

## 你的任务

判断用户的原始问题是否清晰足以进入下一步。不清晰就通过 `AskUserQuestion` 工具追问。

## 判定"是否需要澄清"

**跳过澄清的条件**（三选一即可）：
1. 问题 ≥ 30 字，包含明确的现状、目标、约束
2. 用户已在 `/prism` 后附加了多行描述（视为已澄清）
3. flags 里没有 `--deep`，且问题里没有 deep 触发词（要不要/该不该/深度/彻底），此时可以简版澄清或跳过

**必须澄清的条件**（任一命中）：
1. 问题 < 20 字（信息量不足）
2. 问题模糊（"我该怎么办" / "这个方向好不好" 这类）
3. `--deep` 显式指定，或问题命中 deep 关键词

## 澄清的深度：按档位

### standard 档（默认）
追问 **1~2 个关键背景**，不要问太多打扰用户。示例：

```
AskUserQuestion({
  question: "老大，我先补两个背景就开工：",
  questions: [
    {
      header: "使用场景",
      question: "这个决策主要影响的是？",
      options: [
        { label: "工作 / 项目", description: "职业方向、技术选型、业务决策" },
        { label: "投资 / 财务", description: "买入卖出、资金分配" },
        { label: "个人生活", description: "生活规划、消费决策" }
      ],
      multiSelect: false
    },
    {
      header: "时间紧迫度",
      question: "多久内要决策？",
      options: [
        { label: "本周", description: "紧急" },
        { label: "本月", description: "中等" },
        { label: "3 个月+", description: "从容" }
      ],
      multiSelect: false
    }
  ]
})
```

### deep 档
追问 **5 个维度**（现状/问题/目标/约束/时间），一次问全，不要来回打扰：

```
AskUserQuestion({
  question: "老大，deep 档我需要先摸清 5 件事：",
  questions: [
    { header: "现状", question: "目前情况是什么？", options: [自由填写 / 三个常见选项] },
    { header: "问题触发", question: "什么触发了这个问题？", options: [...] },
    { header: "目标", question: "想达到什么状态？", options: [...] },
    { header: "约束", question: "不能做什么 / 边界在哪？", options: [...] },
    { header: "时间", question: "什么时候要答案 / 什么时候要执行？", options: [...] }
  ]
})
```

## 拼装 clarified_question

用户回答完后，把 raw_question 和答案组织成一段结构化描述：

```
【问题】<raw_question>

【背景】
- <维度1>：<用户回答>
- <维度2>：<用户回答>
- ...
```

## 设置 clarity_level

- 用户回答齐全 → `clarity_level = "high"`
- 用户跳过 / 回答含糊 → `clarity_level = "low"`（S05 时会传一个"背景补充有限"提示给专家）

## 分支处理

| 情况 | 处理 |
|---|---|
| 用户拒绝澄清（比如说"我就是这个问题不用问了"） | 尊重用户，clarity_level=low，直接用 raw_question 进 S02 |
| 用户在澄清过程中改主意（"算了不用这个"） | 优雅退出，不留归档 |
| 用户说"你自己判断" | 用启发式判断（deep 关键词、时间/影响面），clarity_level=medium |

## 完成后

把 `session_state.clarified_question` 和 `session_state.clarity_level` 填好，进入 **S02**：读取 `core/02-router.md`。

## 不做的事

- ❌ 不追问超过 5 个维度（哪怕 deep 档也不超）
- ❌ 不重复追问同一维度
- ❌ 不假设用户懂技术术语，用大白话
- ❌ 不在澄清阶段就给方案建议（那是 S15 的活）
