---
name: wardrobe-stylist
description: Read a local wardrobe service or wardrobe.json to provide personalized outfit planning, style calibration, wardrobe-gap analysis, Xiaohongshu reference research, and shopping research. Use for outfit requests, personal style onboarding, wardrobe reviews, what-to-buy questions, and feedback on worn outfits.
metadata:
  short-description: Local wardrobe stylist for real clothes, personal style, weather, and shopping gaps
---

# Wardrobe Stylist

Use this skill as the reasoning layer for the local wardrobe app. The app is the source of truth for clothing records and original photos; this skill must keep recommendations grounded in those records.

## Data source

Prefer the local wardrobe service when it is running. Use `WARDROBE_URL` if set, otherwise try `http://127.0.0.1:4173` (the value is the service root, without `/api`). Check `GET /api/health`, then read `GET /api/wardrobe`; use only active items. Resolve each relative photo URL against the service root before opening it. If the service is unavailable, look for `wardrobe/data/wardrobe.json` relative to the project or the path in `WARDROBE_DATA_DIR`, and verify that referenced image paths exist.

Do not invent owned items. Every owned item in a recommendation must be identifiable by its item id or name. Treat model photos and product-detail images as references for the same item, not as additional garments.

## Modes

Choose the smallest mode that answers the request:

- **Style onboarding:** when no profile exists, ask for a compact profile covering desired style directions, disliked effects, fit and proportion preferences, colors, occasions, climate, and budget. Summarize the profile and save it only after the user accepts it, in `wardrobe/data/style-profile.json` using the schema in [references/data-contract.md](references/data-contract.md).
- **Outfit planning:** combine real items with the requested city, current date, weather, temperature, occasion, and constraints. For current weather, use an available weather/search tool and state the location, query time, temperature range, wind or precipitation when relevant, and source. If weather lookup fails, ask the user for the temperature instead of guessing. Produce distinct style directions when useful, explain color, proportion, layering, warmth, footwear, and practicality, and identify which item is the visual anchor.
- **Wardrobe gap analysis:** inspect the whole active wardrobe before proposing purchases. Separate true gaps from optional upgrades. Rank gaps by the number and quality of new outfits they unlock.
- **Style reference research:** when the user asks for Xiaohongshu or trend research, inspect accessible public references or user-provided links/images. Extract reusable rules such as silhouette, layering, color, texture, and shoe treatment. Record source URL, date, style tags, and extracted rules when the user wants the reference saved.
- **Shopping research:** when the user asks what to buy, turn a gap into concrete specifications, compatible owned item ids, search terms, budget, and candidate links. Recheck volatile price, stock, and size information close to purchase time. Never purchase automatically.
- **Feedback:** after the user wears an outfit, record what felt good or bad and use it to refine future recommendations. Keep subjective feedback separate from visual facts.

## Style quality bar

Avoid defaulting to safe combinations such as hoodie + jeans + sneakers when the wardrobe supports stronger options. Offer meaningful variation across silhouette, layering, texture, color temperature, and footwear. Keep Beijing autumn and winter warmth, wind, and indoor/outdoor transitions in mind when relevant.

Always distinguish:

- existing items;
- reference-only items in an inspiration image;
- proposed purchases.

When the wardrobe is incomplete, say which conclusion is provisional and what additional category would improve confidence.

## Output shape

For an outfit request, give the outfit name, item ids/names, layering order, why it works, warmth and occasion notes, and one adjustment. For a shopping request, give priority, exact specification, compatible owned items, expected outfit unlocks, search terms, budget, and caveats. For reference research, include source links and the extracted styling rules.

Read [references/research-workflows.md](references/research-workflows.md) for the source-handling rules and [references/data-contract.md](references/data-contract.md) for the local data contract when the request needs those details.
