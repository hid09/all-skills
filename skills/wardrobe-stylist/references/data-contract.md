# Local data contract

The local app stores the source data under `wardrobe/data/`:

- `wardrobe.json`: generated active-item manifest with stable item ids and relative photo paths.
- `images/original/`: preserved original photos.
- `images/thumbs/`: display copies.
- `wardrobe.db`: authoritative local SQLite store.
- `style-profile.json`: optional personal style profile created during onboarding. Use this shape:

  ```json
  {
    "version": 1,
    "updated_at": "ISO-8601",
    "style_directions": [],
    "avoid": [],
    "fit_preferences": [],
    "color_preferences": [],
    "occasions": [],
    "climate": { "city": "", "season": "" },
    "budget": { "currency": "CNY", "typical_item_range": "" },
    "confidence": "draft|confirmed",
    "source": "user conversation"
  }
  ```
- `outfits.json`: optional saved outfit decisions.
- `feedback.json`: optional wear feedback.

The service is the preferred read path because it returns current photo ordering, source labels, and item status. A photo's source label describes the image (`实拍`, `模特`, `商品详情图`, or `其他`), not a separate clothing item. Derived records should retain a `version` and `updated_at`; when writing JSON, use a temporary file followed by an atomic rename and preserve prior history instead of replacing it blindly.

When saving derived records, preserve the original item ids and photo paths. Do not copy or rename original images just to create a recommendation.
