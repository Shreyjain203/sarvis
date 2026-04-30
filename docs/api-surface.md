# Sarvis — API surface
> Public method signatures future Claude is most likely to call. Skip private helpers, Codable boilerplate, and trivial getters.
> Full architecture context → STATE.md. File locations → docs/codemap.md.

---

## Storage

### RawStore (`RawStore.shared`, `@MainActor`)
```
RawStore.shared.add(_ entry: RawEntry)
  Persists entry as Documents/raw/<id>.json and appends to `entries`.

RawStore.shared.unprocessed() -> [RawEntry]
  Returns entries where processed == false.

RawStore.shared.markProcessed(_ id: UUID)
  Sets processed=true, stamps processedAt, rewrites file.

RawStore.shared.setNotificationID(for id: UUID, _ notificationID: String?)
  Writes scheduled notification ID back onto the raw entry file.

RawStore.shared.delete(_ id: UUID)
  Removes file + in-memory record.
```
Published: `entries: [RawEntry]`

### TodoStore (`TodoStore.shared`)
```
TodoStore.shared.capture(text: String, type: InputType? = nil, importance: Importance = .medium, isSensitive: Bool = false, dueAt: Date? = nil) -> TodoItem
  Writes RawEntry only (NOT to processed). Returns synthesized in-memory TodoItem whose id == raw id. Call RawStore.setNotificationID after scheduling.

TodoStore.shared.add(_ item: TodoItem)
  Appends and writes to Documents/processed/<type>.json.

TodoStore.shared.update(_ item: TodoItem)
  Replaces by id; rewrites type file(s).

TodoStore.shared.delete(_ id: UUID)
  Removes from `items`, rewrites the type file atomically, and cancels any
  pending `notificationID` on the deleted item via NotificationService.

TodoStore.shared.toggleDone(_ id: UUID)
  Stamps/clears completedAt.

TodoStore.shared.items(in type: InputType) -> [TodoItem]
TodoStore.shared.todayItems -> [TodoItem]           // tasks due today, sorted by importance desc
TodoStore.shared.sensitiveItems -> [TodoItem]       // today's sensitive items
```
Published: `items: [TodoItem]`

### ProfileStore (`ProfileStore.shared`, `@MainActor`)
```
ProfileStore.shared.save(_ updated: Profile)
  Replaces profile and writes Documents/processed/profile.json atomically.

ProfileStore.shared.merge(_ partial: [String: Any])
  Merges "preferences": [String:String] and/or "traits": [String] into stored profile.
```
Published: `profile: Profile`

### DailyArtifactStore (`DailyArtifactStore.shared`)
```
DailyArtifactStore.shared.read<T: Codable>(folder: String, date: Date) -> T?
  Reads Documents/processed/<folder>/<YYYY-MM-DD>.json. Returns nil if missing.

DailyArtifactStore.shared.write<T: Codable>(_ value: T, folder: String, date: Date)
  Writes Documents/processed/<folder>/<YYYY-MM-DD>.json atomically.
```
Common folders: `"news"`, `"email"`, `"plans"`.

### NewsCache (value type)
```
NewsCache().write(_ articles: [NewsArticle], for date: Date) throws
  Atomic write to Documents/cache/news/<YYYY-MM-DD>.json.

NewsCache().read(for date: Date) -> [NewsArticle]?

NewsCache().delete(articleID: String, for date: Date) -> [NewsArticle]?
  Atomic rewrite. Removes the article matching `id` (== url) from the cached
  list for `date` and returns the updated list, or nil if no file/no match.
```

### EmailCache (value type)
```
EmailCache().saveToday(_ items: [EmailItem])
EmailCache().loadToday() -> [EmailItem]?
EmailCache().save(_ items: [EmailItem], for date: Date)
EmailCache().load(for date: Date) -> [EmailItem]?
EmailCache().clearAll()
  Removes all files under Documents/cache/email/. Call on Gmail disconnect.
```

### KeychainService (enum namespace, no instance)
```
KeychainService.save(_ value: String, for key: String) throws
KeychainService.read(_ key: String) -> String?
KeychainService.delete(_ key: String)
```
Key constants in use: `"anthropic_api_key"`, `"gnews_api_key"` (legacy), `GoogleAuth.refreshTokenKey = "gmail_refresh_token"`.

---

## LLM

### LLMService (instantiate per caller; no shared singleton)
```
LLMService().ask(systemPrompt: String, prompt: String) async -> String?
  One-shot call with default options.

LLMService().ask(systemPrompt: String, prompt: String, options: LLMOptions?) async -> String?
  One-shot with option overrides (e.g. bump maxTokens for batch JSON).

LLMService().send(_ text: String) async
  Appends to `messages` and runs; for interactive chat.

LLMService().reload()
  Re-reads API key from Keychain + model/maxTokens from UserDefaults.
```
`LLMOptions` defaults: model `"claude-opus-4-7"`, maxTokens 1024, temperature 1.0.
Published: `messages: [LLMMessage]`, `isSending: Bool`, `lastError: String?`

### AnthropicProvider
```
AnthropicProvider(apiKey: String).send(messages: [LLMMessage], options: LLMOptions) async throws -> String
  POST https://api.anthropic.com/v1/messages. Throws LLMError on non-2xx or decode failure.
```

### ClassifierService (`ClassifierService.shared`, `@MainActor`)
```
ClassifierService.shared.classifyUnprocessed() async throws -> ClassifierReport
  Reads all unprocessed raws, calls LLM (maxTokens bumped to 4096), distributes TodoItems,
  marks raws processed only after successful write, schedules notifications, merges profile deltas.
  Returns ClassifierReport(itemsAdded:rawsMarked:notificationsScheduled:).
  Throws ClassifierError (.alreadyRunning | .llmFailed | .badJSON).
```
Published: `isRunning: Bool`, `lastRun: ClassifierDebugRecord?`
`var lastLLMError: String?` — last error from underlying LLMService.

### PromptLibrary (enum namespace)
```
PromptLibrary.body(for name: String, fallback: String) -> String
  Loads <name>.md from bundle Resources/Prompts/, strips YAML header above first `---`.
  Returns fallback if file is missing or empty.
```
Prompt names: `basic_app`, `capture_cleanup`, `capture_classify`, `daily_update`, `classify_input`, `sensitive_detect`, `news_summary`, `quote_pick`, `email_classify`.

---

## News

### NewsService (`NewsService.shared`, `@MainActor`)
```
NewsService.shared.refreshToday(country: String = "us", limit: Int = 10) async throws -> [NewsArticle]
  Fetches via RssProvider, writes to NewsCache, returns articles.

NewsService.shared.articlesForToday() -> [NewsArticle]?
  Returns cached articles without network call.
```
Default provider: `RssProvider()`. `GNewsProvider` deprecated — don't use.

### RssProvider (value type, implements `NewsProvider`)
```
RssProvider().fetchTopHeadlines(country: String, limit: Int) async throws -> [NewsArticle]
  Fetches https://news.google.com/rss/search?q=<topic>. Topic from UserDefaults["sarvis_news_topic"].
```
`RssProvider.topicDefaultsKey = "sarvis_news_topic"`, `RssProvider.defaultTopic = "top news"`.

---

## Email

### GoogleAuth (`GoogleAuth.shared`, `@MainActor`)
```
GoogleAuth.shared.authorize() async throws
  PKCE OAuth flow via ASWebAuthenticationSession. Throws EmailError.authFailed if client ID missing.

GoogleAuth.shared.accessToken() async throws -> String
  Returns valid access token; auto-refreshes if expired.

GoogleAuth.shared.disconnect()
  Deletes refresh token from Keychain, clears in-memory token, best-effort revoke.
```
`isConnected: Bool` — true iff Keychain has `gmail_refresh_token`.
Published: `email: String?` — connected account address.
Client ID source: `Info.plist["GoogleOAuthClientID"]` (set via xcconfig `GOOGLE_OAUTH_CLIENT_ID`).

### GmailProvider (implements `EmailProvider`)
```
GmailProvider().fetchRecent(limit: Int, since: String? = "newer_than:1d") async throws -> [EmailItem]
  Two-call Gmail REST: list IDs → fetch metadata. Snippet truncated to 200 chars. 401 auto-refreshes.
```

### EmailDigestService (`EmailDigestService.shared`, `@MainActor`)
```
EmailDigestService.shared.refreshToday(limit: Int = 20) async throws -> EmailDigest
  Fetch → cache → LLM classify (email_classify prompt) → DailyArtifactStore write at "email".
  No-op if !GoogleAuth.shared.isConnected.

EmailDigestService.shared.todaysDigest() -> EmailDigest?
  Reads Documents/processed/email/<today>.json without network call.

EmailDigestService.shared.deleteEmail(id: String) -> EmailDigest?
  Removes one EmailItem (Gmail msg ID) from today's digest across all 3
  buckets (important/fyi/promo) AND drops any extracted actions whose
  sourceMessageID matches. Atomic rewrite via DailyArtifactStore. Returns
  the updated digest, or nil if no digest on disk / nothing matched.

EmailDigestService.shared.deleteAction(id: String) -> EmailDigest?
  Removes one EmailAction (matched by EmailAction.id). Atomic rewrite.
  Returns the updated digest, or nil if no match.
```
Published: `isRunning: Bool`, `lastError: Error?`

---

## Notifications + Jobs

### NotificationService (`NotificationService.shared`)
```
NotificationService.shared.requestAuthorization() async throws -> Bool
NotificationService.shared.registerCategories()
  Registers: TODO_REMINDER, task.reminder, news.briefing, quote.morning.

NotificationService.shared.schedule(_ todo: TodoItem, at date: Date) async throws -> String
  Schedules task.reminder category notification. Returns notification ID.

NotificationService.shared.schedule(title: String, body: String, at: Date, importance: String = "med") async throws -> String
  Lightweight overload for classifier-inferred notifications. Returns notification ID.

NotificationService.shared.cancel(_ id: String)
```
Category constants: `categoryTaskReminder = "task.reminder"`, `categoryNewsBriefing = "news.briefing"`, `categoryQuoteMorning = "quote.morning"`.
`userInfo` keys per category — task.reminder: `todoID`, `importance`, `dueAt`; news.briefing: `headline`, `bullets`; quote.morning: `quote`, `attribution`.

### MorningJob (enum namespace, `@MainActor`)
```
MorningJob.register()
  Must be called in App.init() before app finishes launching.

MorningJob.scheduleNext()
  Submits BGAppRefreshTaskRequest targeting next 7 AM.
```
`taskID = "com.shrey.sarvis.morning"`

### QuoteJob (enum namespace, `@MainActor`)
```
QuoteJob.scheduleDailyPings()
  Cancels existing pings, schedules two UNCalendarNotificationTriggers (9:30 AM + 14–18h).
  Call on every app launch.
```

### QuoteService (`QuoteService.shared`, `@MainActor`)
```
QuoteService.shared.loadAll() -> [Quote]
  Bundle seed.json + Documents/processed/quotes.json, deduped on text.

QuoteService.shared.random() -> Quote?

QuoteService.shared.isSeed(_ quote: Quote) -> Bool
  True if `quote` lives in the bundled seed.json (matched on lowercased text).
  Seed quotes are immutable — the UI uses this to suppress the swipe-delete
  action.

QuoteService.shared.delete(_ quote: Quote) -> Bool
  Atomic rewrite of Documents/processed/quotes.json; removes the quote whose
  lowercased text matches. No-ops (returns false) on bundled seed quotes.
  Returns true iff the file was actually mutated.
```

---

## UI Composer

### ElementRegistry (`ElementRegistry.shared`, `@MainActor`)
```
ElementRegistry.shared.register(_ type: String, factory: (ElementSpec, ScreenState) -> AnyView)
  Register a new element type key.

ElementRegistry.shared.make(_ spec: ElementSpec, state: ScreenState) -> AnyView
  Produces the view for a spec or falls back to UnknownElementView.

ElementRegistry.shared.registerBuiltIns()
  Wires all built-in elements. Called once from SarvisApp.init().
```
Built-in type keys: `"Input/TextInput"`, `"Input/CalendarPicker"`, `"Input/TypeChip"`, `"Input/ImportancePicker"`, `"Input/ToggleRow"`, `"Input/ShoppingItem"`, `"Display/SummaryCard"`, `"Display/ActionButton"`, `"Display/TodoListRow"`, `"Display/NotesListRow"`, `"Display/ShoppingListRow"`, `"Display/DiaryEntry"`, `"Display/QuoteCard"`, `"Display/NewsHeadline"`.

### ScreenState (`@MainActor ObservableObject`)
```
ScreenState().binding(for key: String, default: AnyCodableValue) -> Binding<AnyCodableValue>
ScreenState().string(for key: String) -> String?
ScreenState().bool(for key: String) -> Bool?
ScreenState().reset()
```

### ScreenDefinition + ElementSpec (data types)
```
ScreenDefinition — top-level data object describing a full screen (id, title, elements: [ElementSpec]).
ElementSpec      — one element: type (String key), bindingKey (String), config ([String: AnyCodableValue]).
DynamicScreen    — SwiftUI View that renders a ScreenDefinition.
```

---

## Models (Codable, mostly Codable boilerplate — key fields only)

| Type | Key fields |
|---|---|
| `TodoItem` | id, text, importance: Importance, isSensitive, type: InputType, createdAt, dueAt, isDone, notificationID, completedAt |
| `RawEntry` | id, text, importance, isSensitive, suggestedType: InputType?, dueAt, capturedAt, processed, processedAt, notificationID |
| `InputType` | task/note/idea/sensitive/other/diary/suggestion/shopping/quote. `.fileName` gives the processed/ JSON filename |
| `Importance` | low/medium/high/critical. `.notifString` gives the userInfo value ("low"/"med"/"high"/"critical") |
| `Profile` | preferences: [String:String], traits: [String], updatedAt |
| `NewsArticle` | title, description?, url, source?, publishedAt |
| `EmailItem` | id (Gmail msg ID), threadID, subject, sender, snippet (≤200 chars), receivedAt |
| `EmailDigest` | date, important: [EmailItem], fyi: [EmailItem], promo: [EmailItem], actions: [EmailAction] |
| `EmailAction` | text, sourceMessageID, dueAt? |
| `Quote` | text, author? |
| `LLMMessage` | id, role: LLMRole, content, timestamp |
| `LLMOptions` | model, maxTokens, temperature, systemPrompt? |
