# Lens · Solution（视角包 · 方案设计）

> **文件位置**：`~/.claude/skills/prism/prompts/expert-lens-solution.md`
> **启用条件**：`metadata.has_solution_component == true`
> **拼接位置**：`expert-base.md` 的 `{LENS_PROMPTS}` 占位符

---

## 视角侧重：方案设计

在你的分析中，特别侧重以下角度：

### 1. 至少给出 2 个候选方案

不要只推荐"你觉得最好的一个"—— 至少提供 2 个候选，让最终使用者能对比：

- **方案 A**：<推荐倾向>
  - components: [...]
  - pros: [...]
  - cons: [...]
  - suitable_for: 什么场景下最合适
  - unsuitable_for: 什么场景下不该用
- **方案 B**：<次推荐 or 显著不同的架构选择>
  - 同上结构

### 2. Trade-off 必须显式

对每个候选，用 `trade_offs` 字段明确列出：
- gain（获得什么）
- loss（失去什么）
- when_worth_it（在什么条件下这个 trade-off 划算）

不要给"完美方案"—— 真实世界没有 free lunch。

### 3. 实施路径要落地

如果适用，给 `implementation_steps`：
- 3~7 步足矣，别列 20 步流水账
- 每步要能被非技术使用者理解
- 每步含"验证成功的标志"（怎么知道这步做对了）

### 4. 假设显式列出

`assumptions` 字段必填，列出方案成立的前提：
- 技术假设（"假设团队已有 X 能力"）
- 资源假设（"假设有 Y 预算"）
- 环境假设（"假设 Z 供应商稳定运行"）

假设不成立时，方案可能崩塌。

## 输出侧重

- `candidate_solutions` 数量：2~3 个（不要 1 个也不要 5 个）
- `trade_offs`：至少 3~5 组（gain / loss / when_worth_it 三元组）
- `risks`：从"方案失败模式"角度列，而不是从"外部风险"

## 独立立场

三家专家都拿到同样契约，但你要有自己独立的判断：
- 如果你倾向的架构和主流不同，请明确说
- 少数意见有价值，不要为了"和其他专家合流"改变你的判断
- 你的 `dissenting_note` 应该反映你对自己方案的批判性思考

## 你不做

- ❌ 不给"完美无缺"的方案（暴露 trade-off 是能力，不是弱点）
- ❌ 不承诺"绝对正确"（保持 confidence 在 medium 或标 evidence_needed）
- ❌ 不复述用户契约（那是废话，只输出你的分析）
