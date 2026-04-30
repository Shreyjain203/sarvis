# Library swipe-to-delete

Add iOS-native swipe-to-delete on every row in every Library section. Backend must actually mutate JSON storage (not just hide from UI). Use `.swipeActions(edge: .trailing, allowsFullSwipe: true)` with a destructive `Button(role: .destructive)` — partial swipe reveals the Delete button, full swipe triggers it (Mail/Messages pattern, which is what the user described as "swipe right twice or swipe right once and there's option to delete").

- [x] Load the three nav docs FIRST instead of grepping source: `STATE.md`, `docs/codemap.md`, `docs/api-surface.md`. Use those to identify which stores back which Library sections, what their `@Published` arrays are called, and where the section views live. Only fall back to reading source if a doc-derived answer is insufficient — done; nav docs cover all stores. `TodoStore.delete(_:)` already exists; need to verify it does atomic JSON rewrite. Email digest persisted via `DailyArtifactStore` at `processed/email/<date>.json`. News persisted via `DailyArtifactStore` at `processed/news/<date>.json`.
- [x] Inventory complete:
  - Todo → `TodoStore.items(in: .task)` → `processed/task.json` → `TodoTaskRow` inside `TodoSectionView` (List, already swipe-done) → id `TodoItem.id: UUID`.
  - Notes → `TodoStore.items(in: .note)` → `processed/note.json` → `NoteCard` (VStack/ForEach) → id `TodoItem.id`.
  - Shopping → `TodoStore.items(in: .shopping)` → `processed/shopping.json` → `ShoppingItemCard` → id `TodoItem.id`.
  - Diary → `TodoStore.items(in: .diary)` → `processed/diary.json` → `DiaryCard` → id `TodoItem.id`.
  - Ideas → `TodoStore.items(in: .idea)` → `processed/idea.json` → `NoteCard` → id `TodoItem.id`.
  - Suggestions → `TodoStore.items(in: .suggestion)` → `processed/suggestion.json` → `NoteCard` → id `TodoItem.id`.
  - Quotes → `QuoteService.shared.loadAll()` (bundle seed + `processed/quotes.json`) → `QuoteDisplayCard` → id keyed by `text`. Seed quotes are NOT deletable; only user-captured ones in `processed/quotes.json`.
  - News → `NewsService.shared.articlesForToday()` reads `NewsCache` at `cache/news/<date>.json` → `NewsHeadlineCard` → id `NewsArticle.id == url`.
  - Email → `EmailDigestService.shared.todaysDigest()` reads `processed/email/<date>.json` → `EmailItemRow` (3 buckets: important/fyi/promo) and `EmailActionRow` → id `EmailItem.id` (gmail msg ID), `EmailAction.id`.
  - **Profile excluded** (structured singleton, not a list).
  - All non-Todo sections currently use `VStack { ForEach }`, not `List`. `.swipeActions` requires `List` rows, so each section will be refactored to `List` for the swipe gesture to work. Match TodoSectionView styling: `.listStyle(.plain)`, `.scrollContentBackground(.hidden)`, `.scrollDisabled(true)`, height computed from row count, `.listRowBackground(.clear)` and `.listRowSeparator(.hidden)` to preserve themedCard look.
- [x] Added delete signatures on the four affected stores. Note: `TodoStore` is NOT `@MainActor` (it's a plain `final class : ObservableObject`); existing `add`/`update`/`delete` log write errors rather than throwing, so the new behavior matches the existing pattern (no `try?` swallowing introduced — errors are logged via `print`, same as `writeTypeFile`). Signatures added:
  - Remove from the in-memory `@Published` collection so the UI updates immediately
  - Rewrite the JSON file (atomic write — same pattern as existing `add`/`save` on that store)
  - For `TodoItem` rows: also cancel the scheduled notification via `UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:)` if `notificationID` is non-nil
  - Be `@MainActor` if the store is, to match the existing pattern
  - Return a clean throw/result on failure (don't `try?` swallow)
  - Stores expected to need work: `TodoStore` (covers Todo/Notes/Ideas/Suggestions/Diary/Shopping/Quotes via its per-type files), `EmailCache` or wherever today's `EmailDigest` is read from for Library Email, the news read path for Library News (likely `DailyArtifactStore` for `processed/news/<date>.json` — add a typed helper if needed)
  - Quotes are a special-ish case: user-captured quotes live in `Documents/processed/quotes.json` (alongside seed quotes in the bundle that are not deletable). Only allow deleting user-captured ones — or if the row source mixes seed+captured, gracefully no-op on seed quote IDs. Document the behaviour in code with a one-line comment
- [x] Wired `.swipeActions` on every Library row. Notes/Shopping/Diary/Ideas/Suggestions reuse a new `swipeDeleteList` helper (List + full-swipe destructive button) on `ProcessedView`. Quotes use a custom List that suppresses the swipe action for seed quotes (immutable). News uses a List backed by `NewsCache().delete(articleID:for:)`. Email uses a `emailItemList` helper for important/fyi/promo + a separate List for actions. Todo tiles still have full-swipe Done; added `.swipeActions(edge: .trailing, allowsFullSwipe: false)` with destructive Delete as a second action (per Mail-style spec). CompletedTodosView gets the same Revert + Delete pair.
- [x] `Haptics.light()` fires inside every destructive button action — matches the existing convention from `TodoSectionView` (which uses `.success()` for Done and `.soft()` for revert). Light is the closest existing helper for a tap that mutates state.
- [x] No confirmation alert added. Full-swipe + visible destructive button only.
- [x] No new files added → no `xcodegen generate` needed. `xcodebuild` simulator build returned **BUILD SUCCEEDED**.
- [x] Updated `docs/codemap.md` (TodoStore, NewsCache, EmailDigestService, QuoteService delete entries) and `docs/api-surface.md` (added delete signatures with one-line behavior under each store).
- [x] STATE.md update-log appended; `Last updated` bumped to 2026-04-30.
- [x] Wrote `.dispatch/tasks/library-delete/output.md` with stores, sections, skipped items, seed-quote decision, and build result.
- [x] `.done` marker created.
