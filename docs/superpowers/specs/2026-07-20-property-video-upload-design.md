# Property Video Upload — Design Spec
Date: 2026-07-20

## Overview
Add short video upload (walkthrough-style, ~8 seconds — matching Google AI Studio's free-tier limit) to every property in the app: the 3 rental properties (`PropertyInspectorView`) and the for-sale property (`ForSaleInspectorView`). Videos are produced externally (AI Studio, phone, editor) and imported into the app the same way photos already are — no in-app generation.

One video per property, to keep the local store lean. Uploading a new video replaces the old one.

## Data Model
Add an optional field to both property models, following the existing optional-field convention (`Property.monthlyPrice`):

**`Property.swift`**
```swift
var videoURL: URL?
```
- `CodingKeys`: `case videoURL = "video_url"`
- Decode with `try?` like the other optional fields — existing `properties.json` entries without this key simply decode to `nil`, no migration needed.

**`ForSaleProperty.swift`**
```swift
var videoURL: URL?
```
Same `try?`-decode treatment; `ForSaleStore` needs no changes beyond the model gaining the field (it already round-trips whatever `ForSaleProperty` encodes).

## Storage
Mirrors the existing photo-copy pattern in each inspector view:
- Rentals: `Application Support/CozumelManager/Videos/<property.id>/<filename>`
- For sale: `Application Support/CozumelManager/Videos/forsale/<property.id>/<filename>`

On replace: delete the old file at the previous `videoURL` (if any) before copying in the new one and updating `draft.videoURL`.

## UI — new "Video" section
Added to both `PropertyInspectorView` and `ForSaleInspectorView`, placed after the Photos section.

**No video set:**
- "Add Video" button (same style as "Add Photos"), opens `NSOpenPanel` with `allowedContentTypes = [.movie]`, single selection only (`allowsMultipleSelection = false`).

**Video set:**
- Inline AVKit `VideoPlayer(player:)` showing the clip with native play/pause/scrub controls, sized similarly to the photo grid area (e.g. `frame(height: 200)`).
- A "Replace Video" button and a trash/remove button next to it.

**Duration check on import:**
- Load the picked file's duration via `AVURLAsset(url:).load(.duration)` (async).
- If duration > 8 seconds, show a non-blocking `alert` — "This video is Xs, longer than the 8s AI Studio limit — uploaded anyway." — then proceed with copy + save regardless of the user's dismissal.
- No hard block; any playable video file is accepted.

## Modified Files
| File | Change |
|---|---|
| `Models/Property.swift` | Add `videoURL: URL?` + coding key |
| `Models/ForSaleProperty.swift` | Add `videoURL: URL?` |
| `Views/PropertyInspectorView.swift` | Add Video section (picker, player, replace/remove, duration check) |
| `Views/ForSaleInspectorView.swift` | Same Video section |

## Out of Scope
- In-app AI video generation (Google AI Studio API integration)
- Multiple videos per property
- Video compression/transcoding
- Uploading videos to the companion website (Phase 2c work, not this app)
