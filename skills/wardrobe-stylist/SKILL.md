---
name: wardrobe-stylist
description: Read an explicitly configured local wardrobe service or wardrobe manifest to provide personalized outfit planning, style calibration, wardrobe-gap analysis, trend-aware public style-reference research, and shopping research. Use for outfit requests, personal style onboarding, wardrobe reviews, trend adaptation, what-to-buy questions, and feedback on worn outfits. Works without a service in read-only mode and never includes private wardrobe data in a shared package. Do not use it to bulk-scrape login-only social sites or place purchases.
metadata:
  short-description: Local wardrobe stylist for real clothes, personal style, weather, and shopping gaps
---

# Wardrobe Stylist

Use this skill as the reasoning layer for a local wardrobe app or an imported wardrobe manifest. The configured data source is the source of truth for clothing records and original photos; keep recommendations grounded in those records. This package contains instructions and schemas only: never add a user's photos, database, profile, tokens, cookies, or exported wardrobe data to the Skill directory or a distributable archive.

## Safety, consent, and portability

- Read only the configured source. Do not scan unrelated folders, infer ownership from arbitrary images, or upload local photos/data without explicit user consent.
- Treat wardrobe records, body/fit preferences, locations, budgets, and feedback as private personal data. Show only the minimum needed for the requested answer and do not expose absolute local paths in a shareable response.
- Before writing a profile, outfit, or feedback record, confirm the user asked to save it. Keep a backup/history and use the atomic-write rule in [references/data-contract.md](references/data-contract.md).
- A fresh installation must work with no service and no personal data: explain how to set `WARDROBE_URL` or `WARDROBE_DATA_DIR`, then offer onboarding or a clearly labeled generic answer. Never pretend that an empty or invalid manifest is a real wardrobe.
- If the service or manifest fails validation, report the exact missing field or unavailable capability and continue in read-only/manual-input mode when possible.

## Data source

Prefer the local wardrobe service when it is running. Use `WARDROBE_URL` if set, otherwise try `http://127.0.0.1:4173` (the value is the service root, without `/api`). Check `GET /api/health`, then read `GET /api/wardrobe`; use only active items and validate stable ids, names, status, and photo paths before reasoning. Resolve each relative photo URL against the service root before opening it. If the service is unavailable, use only the explicitly configured `WARDROBE_DATA_DIR`; otherwise look for `wardrobe/data/wardrobe.json` relative to the project. Verify referenced image paths exist, and label missing photos as unavailable instead of guessing from filenames.

For a new installation, set `WARDROBE_DATA_DIR` to that user's private data directory (for example, `./wardrobe/data` in an application project) or configure a compatible `WARDROBE_URL`. Keep the data directory outside the Skill package when distributing it. If neither is configured, start with onboarding/manual input and explain that no owned-item recommendations can be grounded yet.

The service is optional. If health, authentication, schema, or network access fails, do not retry indefinitely: state the failure, switch to the manifest if explicitly available, or ask for a small manual item list. Never call a remote endpoint merely because a product or image URL appears in a record.

Do not invent owned items. Every owned item in a recommendation must be identifiable by its item id or name. Treat model photos and product-detail images as references for the same item, not as additional garments.

## Modes

Choose the smallest mode that answers the request:

- **Style onboarding:** when no profile exists, ask for a compact profile covering desired style directions, disliked effects, fit and proportion preferences, colors, occasions, climate, and budget. Summarize the profile and save it only after the user accepts it, under the resolved private data directory as `style-profile.json`, using the schema in [references/data-contract.md](references/data-contract.md).
- **Outfit planning:** combine real items with the requested city, date/time zone, weather, temperature, occasion, and constraints. For current weather, use an available weather/search tool and state the location, query time, temperature range, wind or precipitation when relevant, and source. If lookup fails or the city is missing, ask for temperature/precipitation or give a conditional plan with the uncertainty clearly labeled; never guess current conditions. Produce distinct style directions when useful, explain color, proportion, layering, warmth, footwear, and practicality, and identify which item is the visual anchor.
- **Wardrobe gap analysis:** inspect the whole active wardrobe before proposing purchases. Separate true gaps from optional upgrades. Rank gaps by the number and quality of new outfits they unlock.
- **Style reference research:** when the user asks for Xiaohongshu or trend research, inspect accessible public references or user-provided links/images. Respect login, robots, copyright, and rate limits; do not bulk scrape or bypass controls. Extract reusable rules such as silhouette, layering, color, texture, and shoe treatment. Record source URL, date, style tags, and extracted rules only when the user wants the reference saved.
- **Trend-aware styling:** when the user asks for current fashion or Xiaohongshu-inspired styling, gather a small set of accessible public references or user-provided screenshots/links, record source and capture time, and extract reusable rules instead of copying a creator's full look. Classify each rule as current trend, durable staple, or personal-style hypothesis; then map it to existing items and offer conservative, balanced, and expressive versions. Never treat a reference garment as owned inventory.
- **Shopping research:** when the user asks what to buy, turn a gap into concrete specifications, compatible owned item ids, search terms, budget, and candidate links. Separate observed facts from recommendations; recheck volatile price, stock, shipping, and size information close to purchase time and include the check time/source. If browsing is unavailable, provide specifications and search terms without inventing links or prices. Never purchase automatically.
- **Feedback:** after the user wears an outfit, record what felt good or bad and use it to refine future recommendations. Keep subjective feedback separate from visual facts.

## Style quality bar

Avoid defaulting to safe combinations such as hoodie + jeans + sneakers when the wardrobe supports stronger options. Offer meaningful variation across silhouette, layering, texture, color temperature, and footwear. Use the user's specified city, season, temperature, wind, precipitation, and indoor/outdoor transitions when relevant; do not assume a particular climate.

Always distinguish:

- existing items;
- reference-only items in an inspiration image;
- proposed purchases.

When the wardrobe is incomplete, say which conclusion is provisional and what additional category would improve confidence.

For every recommendation, check the requested occasion, weather risk, fit/proportion constraints, color preferences, budget, and whether each named owned item is active and identifiable. If any check cannot be performed, mark it as unknown and ask only for the missing input that changes the recommendation.

## Output shape

For an outfit request, give the outfit name, item ids/names, layering order, why it works, warmth and occasion notes, and one adjustment. For a shopping request, give priority, exact specification, compatible owned items, expected outfit unlocks, search terms, budget, and caveats. For reference research, include source links and the extracted styling rules.

Read [references/research-workflows.md](references/research-workflows.md) for the source-handling rules and [references/data-contract.md](references/data-contract.md) for the local data contract when the request needs those details.

## Shareable delivery checklist

Before publishing or handing this Skill to another person, verify that the package contains only `SKILL.md`, `references/`, and `agents/openai.yaml`; all paths are relative or configurable; no personal files, absolute user paths, secrets, cookies, or sample wardrobe records are included; the first-run behavior works with an empty data directory; and the service, weather, research, and write failures have explicit fallbacks.
