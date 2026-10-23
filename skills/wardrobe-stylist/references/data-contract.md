# Local data contract

This is a portable contract for a user's own data. It is not a fixture: do not commit real wardrobe records, photos, SQLite files, or profile values to the Skill package.

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

## Minimum validation

Before using a record, require a stable non-empty `id`, a non-empty display `name`, and an explicit active/deleted status. Treat unknown status as unavailable. A valid photo entry has a relative or service-relative path and a source label; reject absolute paths from shareable exports and do not follow paths outside the configured data directory. Ignore unknown fields for forward compatibility, but preserve them when writing records.

An item is one garment/accessory record. A photo is evidence attached to that item. Multiple photos in one upload batch remain one item unless the user explicitly separates them. Photo source labels (`实拍`, `模特`, `商品详情图`, `其他`) describe the image only and must never increment item counts or category totals.

The service is the preferred read path because it returns current photo ordering, source labels, and item status. A photo's source label describes the image (`实拍`, `模特`, `商品详情图`, or `其他`), not a separate clothing item. Derived records should retain a `version` and `updated_at`; when writing JSON, use a temporary file followed by an atomic rename and preserve prior history instead of replacing it blindly.

When saving derived records, preserve the original item ids and photo paths. Do not copy or rename original images just to create a recommendation. Write only after explicit user intent, use a temporary file plus atomic rename, preserve a timestamped prior version, and avoid storing raw image bytes or unnecessary personal metadata in derived files.

For a distributable example, use placeholders such as `item-001` and `images/example.jpg` only; never include a real person's location, body measurements, budget history, or identifying photo metadata.
