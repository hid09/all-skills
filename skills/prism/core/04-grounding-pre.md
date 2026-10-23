# core/04-grounding-pre.md · 前置 Grounding

## 你的任务
在契约生成前，搜集共享事实基础，供三家专家共同使用。

## 输入
- `clarified_question`
- `metadata.fact_density`

## 处理
```
search_budget = {"low": (0, 1), "medium": (2, 3), "high": (5, 10)}[fact_density]

facts = []
level = "L0"
for i in range(search_budget[1]):
    try:
        query = derive_query_from(clarified_question, i)  # 生成第 i 个搜索关键词
        result = WebSearch(query)
        if not result or len(result) == 0:
            # 部分不可用
            if level == "L0": level = "L1"
            continue
        # 取前 3 条相关的
        for r in result[:3]:
            facts.append({
                "fact": r.summary,
                "source": r.url,
                "verified_at": now(),
                "reliability": estimate(r)  # "high" | "medium" | "low"
            })
    except SearchUnavailable:
        level = "L2"
        break
    except QuotaExceeded:
        level = "L1"
        break
```

## 三级降级处理
- **L0 正常**：facts 数量达到 search_budget[0]（下限）以上 → 静默继续
- **L1 部分降级**：搜到一些但不够，或某些 query 失败 → 汇报"⚠️ 部分事实未查证，报告会标注"
- **L2 完全不可用**：完全搜不到 → 触发用户询问：
  ```
  🔴 WebSearch 完全不可用，本次只能出未验证报告
  您要继续吗？
  [Y] 继续（报告顶部会有红色警示头）
  [N-单答] 让我作为单个 Claude 直接给参考答案
  [N-终止] 直接结束
  ```

## 输出
- `shared_facts[]`
- `grounding_level ∈ {"L0", "L1", "L2"}`

## 汇报
```
"🔍 前置 Grounding 完成：搜了 {n} 条事实，等级 {level}"
```

## 完成后
进入 **S05** contract-builder。

---
