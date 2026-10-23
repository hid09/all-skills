# core/12-grounding-post.md · 后置 Grounding

## 你的任务
S10 循环体的第 ⑨~⑩ 步：只搜标了 evidence_needed=true 的字段。

## 缓存约束
- 每个 fact 全流程最多搜 1 次
- 缓存 key = SHA256(fact_text 的规范化字符串)
- 缓存值 = {status: "verified|unverified|disproved", source: "...", checked_at: "..."}

## 搜索策略
```
for claim in integrated_versions[round].key_claims:
    if not claim.evidence_needed: continue
    cache_key = hash(claim.claim)
    if cache_key in fact_cache:
        claim.verification_status = fact_cache[cache_key].status
        continue

    try:
        result = WebSearch(derive_query(claim.claim))
        if result and matches(result, claim.claim):
            claim.verification_status = "verified"
            fact_cache[cache_key] = {"status": "verified", "source": result.url}
        elif result and contradicts(result, claim.claim):
            claim.verification_status = "disproved"
            fact_cache[cache_key] = {"status": "disproved", "source": result.url}
            add_error_to_claim_table(claim)  # 打回给专家下一轮修
        else:
            claim.verification_status = "unverified"
            fact_cache[cache_key] = {"status": "unverified"}
    except:
        claim.verification_status = "unverified"
```

## 输出
- 更新 `session_state.integrated_versions[round]` 中每个 evidence_needed claim 的 verification_status
- 更新 `session_state.claim_table` 增加 disproved 项

## 完成后
返回 S10 循环体继续第 ⑪ 步。

---
