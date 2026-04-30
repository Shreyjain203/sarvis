# library-delete — output

iOS-native swipe-to-delete shipped on every Library section except Profile.
Mail-style: full-swipe triggers delete; partial swipe reveals the destructive
Delete button. Backend writes are atomic against the existing JSON files.

## Stores modified

| Store | New / changed signature | Behavior |
|---|---|---|
| `TodoStore` | `delete(_ id: UUID)` (extended) | Removes from `items`, rewrites the matching `processed/<type>.json` atomically, cancels any pending `notificationID` via `NotificationService.shared.cancel(_:)`. Errors logged (matches existing `add`/`update` pattern — no throw). |
| `QuoteService` | `isSeed(_:) -> Bool`, `delete(_:) -> Bool` | `isSeed` returns true for bundled seed quotes (immutable). `delete` no-ops on seed quotes; otherwise atomic-rewrites `Documents/processed/quotes.json` with the lowercased-text match removed. |
| `NewsCache` | `delete(articleID:for:) -> [NewsArticle]?` | Removes one article (matched on `id == url`) from the date's cache file via the same atomic temp + replace pattern as `write`. |
| `EmailDigestService` | `deleteEmail(id:) -> EmailDigest?`, `deleteAction(id:) -> EmailDigest?` | `deleteEmail` removes one Gmail message ID across all 3 buckets (important/fyi/promo) AND drops actions referencing it. `deleteAction` removes one extracted action by its synthetic `EmailAction.id`. Both atomic-rewrite `Documents/processed/email/<today>.json` via `DailyArtifactStore`. |

## Sections updated

| Section | Backing read | Row | UX |
|---|---|---|---|
| Todo (tiled timeline) | `TodoStore.items(in: .task)` | `TodoTaskRow` in `TodoSectionView` | Existing full-swipe Done preserved + new partial-swipe Delete (second trailing action). |
| CompletedTodosView | same | | Existing Revert preserved + new Delete. |
| Notes | `TodoStore.items(in: .note)` | `NoteCard` | Section converted from `VStack` to embedded `List`. Full-swipe Delete. |
| Shopping | `TodoStore.items(in: .shopping)` | `ShoppingItemCard` | Same conversion. |
| Diary | `TodoStore.items(in: .diary)` | `DiaryCard` | Same. |
| Ideas | `TodoStore.items(in: .idea)` | `NoteCard` | Same. |
| Suggestions | `TodoStore.items(in: .suggestion)` | `NoteCard` | Same. |
| Quotes | `QuoteService.loadAll()` | `QuoteDisplayCard` | Custom list — bundled seed quotes show no swipe action; user-captured quotes (in `processed/quotes.json`) full-swipe delete. |
| News | `NewsCache.read(for: today)` (via `NewsService.articlesForToday()`) | `NewsHeadlineCard` | Full-swipe delete via `NewsCache.delete(articleID:for:)`. |
| Email | `EmailDigestService.todaysDigest()` | `EmailItemRow`, `EmailActionRow` | Full-swipe delete on items (across all three buckets) + on actions, via the new `EmailDigestService` methods. |

The non-Todo sections were previously plain `VStack { ForEach }`. SwiftUI
`.swipeActions` only works on `List` rows, so each was wrapped in a
`List` with `.scrollDisabled(true)`, `.scrollContentBackground(.hidden)`,
clear row backgrounds and hidden separators to preserve the existing
themedCard look. Inner-list height is clamped to `rowCount * estimatedRowHeight`
so the outer `ScrollView` still owns the scroll. A `swipeDeleteList<T>`
generic helper on `ProcessedView` handles the five `TodoItem`-backed
sections; News, Email, and Quotes have inline lists since their callbacks
are non-uniform.

## Intentionally skipped

- **Profile** — explicitly excluded per spec; structured singleton, not a list.
- **fyi** and **promo** email buckets — the existing UI doesn't render them
  (only `important` and `actions` are shown), so no row to attach a swipe
  action to. The `deleteEmail` API still removes a deleted message from those
  buckets if it ever lived there, keeping the on-disk digest consistent.

## Seed-quote behavior

User-captured quotes live in `Documents/processed/quotes.json`; bundled seed
quotes live in the app's `Resources/Quotes/seed.json` and are immutable.
`QuoteService.delete(_:)` returns `false` and does nothing if asked to delete
a seed quote (gracefully no-op). The Quotes section UI consults
`QuoteService.shared.isSeed(_:)` and renders no destructive swipe action for
seed rows, so the user can't even attempt the delete. User-captured quotes
get a full-swipe Delete that mutates the file and removes from the visible
list.

## Haptics

`Haptics.light()` fires inside every destructive button action — matches the
existing `TodoSectionView` convention (it uses `.success()` for Done and
`.soft()` for Revert; light is the closest existing helper for a state-mutating
tap).

## Build

```
xcodebuild -scheme Sarvis \
  -destination "generic/platform=iOS Simulator" \
  -configuration Debug build
```
**BUILD SUCCEEDED** (Xcode 26.4 simulator, iOS 17 deployment target).

## Files touched

- `Sarvis/Models/TodoStore.swift` — extended `delete(_:)` to cancel notifications.
- `Sarvis/Services/Quotes/QuoteService.swift` — added `isSeed`, `delete`, factored out `accumulatedFileURL`.
- `Sarvis/Services/News/NewsCache.swift` — added `delete(articleID:for:)`.
- `Sarvis/Services/Email/EmailDigestService.swift` — added `deleteEmail(id:)` and `deleteAction(id:)`.
- `Sarvis/Screens/ProcessedView.swift` — converted 5 sections to `List`, added Quotes/News/Email custom swipe lists, added `swipeDeleteList` helper.
- `Sarvis/Screens/TodoSectionView.swift` — added second trailing destructive Delete swipe action to TodoTaskRow rows and to CompletedTodosView rows.
- `docs/codemap.md` — appended new symbols on TodoStore, NewsCache, EmailDigestService, QuoteService.
- `docs/api-surface.md` — appended new delete signatures with behavior.
- `STATE.md` — added 2026-04-30 update-log entry; bumped `Last updated`.

No new files — `xcodegen generate` not needed.
