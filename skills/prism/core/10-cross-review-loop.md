# Prompt · 10 · Cross Review Loop（循环体核心）

> **文件位置**：`~/.claude/skills/prism/core/10-cross-review-loop.md`
> **对应 workflow**：S10
> **输入**：`claim_table` + `expert_versions` (首轮 = S08 输出) + `metadata`
> **输出**：`last_integrated_version` + `convergence_status`
>
> **⚠️ 这是最核心的循环体，也是最复杂的一步。请严格按顺序执行 12 步。**

---

## 你的任务

在专家首轮独立推理后，进入 Cross Review 循环。每轮做 12 件事，直到满足 4 种退出条件之一。

## 循环基本结构

```
round = 1
loop while True:
    执行本轮 12 步（见下方）
    判断退出条件
    if 满足任一退出条件:
        break
    round += 1
    if round > 3:
        force break（convergence_status = "max_rounds"）
```

## 本轮 12 步

### ① 整理本轮差异表

从上一轮的 `claim_table` 和 `expert_versions` 里提取需要讨论的 Claim 组：

- 保留：`type in ("conflict", "single_source")` 的组
- 附加：`type == "consensus" but unverified` 的组（后置 Grounding 打过 ❌ 的）

不包含 `type == "gap"` 组（那是 D_coverage，只提醒不进循环）。

### ② 组装本轮 in.json（三家专家修订）

每家专家的 user_prompt 结构：

```
你是专家 {alias}。这是本轮的 Cross Review 材料：

【你上一版方案】
<expert_versions[round-1][alias]>

【其他专家的匿名方案】
- 专家 {other_alias_1}：<key claims 摘录>
- 专家 {other_alias_2}：<key claims 摘录>

【本轮差异表】
<claim_table 中 conflict / single_source 类的组>

【本轮 shared_facts 补充】
<后置 Grounding 新增或修正的事实>

【你的任务】
1. 阅读其他专家意见
2. 逐条决定：accepted / rejected（rejected 必须给理由）
3. 修订你自己的方案（只改自己 · 禁止辩论其他专家）
4. 输出必须符合 schema-internal.json
5. 强制填 dissenting_note：如果我错了，可能错在哪
```

**匿名约束**：
- 若 `--strict` 且本轮需要重洗代号 → 用新的 alias_map，且 prompt 里明确"以下代号是本轮临时分配，与上一轮无关"
- 否则 → 继续沿用 session_state.alias_map

### ③ 调 panel.ps1（三家并行）

写 `in.json` → 调 `scripts/panel.ps1` → 读 `out.json`。

超时：60 秒 / 家。失败家标 status=failed，用剩下的继续。

### ④ 收集三份修订版

存入 `session_state.expert_versions[round]`。

### ⑤ 组装 Integrator in.json（双 Integrator 并行融合）

**Integrator I**（求同）—— 用 `prompts/integrator-consensus.md`，走 GPT

**Integrator II**（存异）—— 用 `prompts/integrator-divergence.md`，走 Gemini

两个 Integrator 的 user_prompt 都是：

```
以下是三位专家（{alias_A}/{alias_B}/{alias_C}）本轮的修订方案：

<expert_versions[round]>

请融合成一份综合方案。你的融合原则：
- Integrator I：偏"求同"，尽量提取共识和最强主张
- Integrator II：偏"存异"，保留有价值的分歧和少数意见

输出必须符合 schema-internal.json。你不知道自己在合并哪家的方案。
```

### ⑥ 调 panel.ps1（双 Integrator 并行）

同上。

### ⑦ 收两份融合版

存入 `session_state.integrated_versions[round]`。

### ⑧ 计算 D_int

```
D_int = 两份融合版在 recommendation / key_claims / risks / next_steps 字段上的差异度（0~1）

具体算法（简化版）：
  a. 对每个字段，把两份融合版都拆成 claim 列表
  b. 对齐 claim（同一意思归一组）
  c. D_int = 冲突 claim 组数 / 总组数
```

### ⑨ 后置 Grounding（读 core/12-grounding-post.md）

按 `12-grounding-post.md` 的规则做：
- 只搜标了 `evidence_needed: true` 的字段
- 同一 fact 缓存，最多搜 1 次
- 标签 ✅ / ⚠️ / ❌

### ⑩ 处理后置 Grounding 结果

- ❌ 错误 → 打回 claim_table，标记"需要修正"，进入下一轮时会被专家看到
- ⚠️ 无法验证 → 保留，D_uncertainty ↑
- ✅ 通过 → D_uncertainty ↓

### ⑪ 重算三指标 + non_factual_disagreement_check

```
D_conflict    = 真正对立的 Claim 组数 / 总组数（本轮融合后）
D_uncertainty = 未通过 Grounding 的 evidence_needed 字段比例
D_coverage    = Gap 组数 / 总组数（仅提醒）
D_int         = 见 Step 8

# non_factual_disagreement_check
for claim_group in claim_table where type == "conflict":
    Analyst 打标签：fact-based / value-based / preference-based

if any(标签 == "fact-based"):
    check_pass = False  # 事实分歧未消解，不能提前退出
else:
    check_pass = True  # 剩余都是立场/偏好差异，可以退出保留少数意见

grounded = (all evidence_needed 通过 ✅) AND check_pass
```

### ⑫ 退出条件判定

按顺序检查：

```
条件 A（最理想 · 分歧收敛）:
    D_conflict < 0.15
    AND D_uncertainty < 0.25
    AND D_int < 0.20
    → convergence_status = "converged"
    → break

条件 B（硬熔断）:
    round >= 3
    → convergence_status = "max_rounds"
    → break

条件 C（grounded 提前退出）:
    grounded == True
    → convergence_status = "grounded_exit"
    → break

条件 D（用户中断）:
    user_abort == True
    → convergence_status = "user_abort"
    → break

否则:
    round += 1
    继续下一轮
```

## 退出后的处理

选择 `session_state.last_integrated_version`：

- 优先选 Integrator I 的版本（如果它和 Integrator II 差异小）
- 如果 D_int 大，选 Integrator II 的版本（存异派更保守，风险控制更强）
- 若两个 Integrator 都有独有的优点 claim → 手工合并主要 recommendation，其他 claim 附在 `key_claims_display` 里

## 汇报（每轮末给用户一句话）

```
"🔄 第 {round} 轮完成：D_conflict={D_conflict:.2f}, D_uncertainty={D_uncertainty:.2f}, D_int={D_int:.2f}。<继续/退出>"
```

退出时汇报 convergence_status：

```
"✅ 已收敛（converged），进入 Final Audit"
或
"⚠️ 达到 3 轮上限（max_rounds），报告会含未完全收敛的保留意见"
或
"✅ 事实已确认 + 剩余立场差异，提前退出（grounded_exit）"
```

## 完成后

设置 `session_state.last_integrated_version` 和 `session_state.convergence_status`，进入 **S13**：读取 `core/13-auditor.md`。

## 不做的事

- ❌ 不超过 3 轮（哪怕分歧还在）
- ❌ 不把 D_coverage 算进退出条件（Gap 不入门禁）
- ❌ 不强行合并 value-based 分歧
- ❌ 不同一 fact 反复搜（缓存）
- ❌ 不让专家看到品牌信息
- ❌ 不让专家互相辩论（只改自己）
