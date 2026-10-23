# Prompt · 02 · Router（判档位 · V4.2）

> **文件位置**：`~/.claude/skills/prism/core/02-router.md`
> **对应 workflow**：S02
> **输入**：`clarified_question` + `flags`
> **输出**：`depth ∈ {"standard", "deep"}`

---

## 你的任务

根据用户 flag 判定本次流程走 **standard** 还是 **deep**。V4.2 不做 auto 档位判定：`/prism` 默认 deep，`--standard` 才走 standard。

## 决策树（严格按序）

```
if "--standard" in flags:
    depth = "standard"
elif "--deep" in flags:
    depth = "deep"
else:
    depth = "deep"  # V4.2 默认 · 老大 #3
```

**无 lite 档支持。无 quick 档支持。无 mode 分流支持。**

## 主 Agent 可选建议

如果用户无 flag 或显式 `--deep`，但问题明显很轻（低风险、可逆、事实密度低、只需要快速多视角），你可以建议：

```
我建议这题用 --standard 就够，理由：<一句话>。
要切到 standard 吗？(Y/n)
```

用户同意才切换。用户不同意则保持 deep。

## Standard 档池选算法（HC-13）

当 `depth = "standard"` 时，从 `models.json.pools.standard_pool` 中挑 2 家专家。

### 输入

- `config/models.json`
- 可选：`~/.prism/models.local.json`（与出厂 models/pools merge 后）
- `pools.standard_pool`

### 规则

1. 优先选 **provider 不同 + model_type 不同** 的 2 家（1 standard + 1 reasoning）。
2. 若没有，选 **provider 不同 + model_type 相同** 的 2 家。
3. 若仍没有，允许 **同 provider** 兜底，但必须向用户 warning：`异构度不足`。
4. 若池子只剩 1 家，降级为 1 专家，并 warning：`异构度不足`。
5. 若池子为空，报错并提示用户运行 `scripts/init-prism.ps1`。

### 排序偏好

```
a. provider 不同 且 model_type 不同 → 最优
b. provider 不同 且 model_type 相同 → 次优
c. provider 相同                     → 兜底
d. 只有 1 家                         → 降级继续
e. 0 家                              → 报错
```

## standard vs deep 的差异总览

| 阶段 | standard | deep |
|---|---|---|
| 默认入口 | 仅 `--standard` | `/prism` 默认 / `--deep` |
| 专家池 | `standard_pool` 中挑 2 家 | `deep_pool` 中挑 3 家 |
| Integrator | 1 个 Integrator I | deep 原流程 |
| Mini Audit | 1 个 `mini-auditor-combined.md` | deep 原 Final Audit |
| Cross Review | 不跑循环 | 保留 V4.1 12 步循环 |
| 调用结构 | 2 experts + 1 integrator + 1 mini-auditor | V4.1 deep 全流程 |

## 汇报格式

```
⚙️ 本次走 <standard/deep> 档。理由：<flag 或默认规则>。
```

示例：

- `⚙️ 本次走 deep 档。理由：V4.2 默认 /prism 走 deep。`
- `⚙️ 本次走 standard 档。理由：用户显式指定 --standard。`

## 完成后

设置 `session_state.depth`，进入 **S03**：读取 `core/03-intent-detector.md`。

## 不做的事

- 不做 auto standard 判定
- 不支持 lite 档
- 不支持 `--quick`
- 不支持 `--mode research/design/decide`
- 不修改 `core/10-cross-review-loop.md`
