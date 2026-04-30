# Sarvis — codemap
> For future Claude: read this (and api-surface.md) BEFORE grepping. Covers Sarvis/, SarvisWidget/, SarvisNotificationContent/.
> Architecture decisions / phase scope → STATE.md, docs/phase-1.md, docs/phase-2.md.

---

## Sarvis/App/
  SarvisApp.swift         — @main entry. Wires `NotificationService` delegate, registers categories, calls `ElementRegistry.shared.registerBuiltIns()`, `MorningJob.register()`, schedules jobs on appear.
  RootView.swift          — 3-tab `TabView` (.page style). Tabs in order: `InputView` (capture), `ProcessedView` (library), `TodayView` (entries). Handles `sarvis://capture` deep link → `QuickCaptureSheet`. Custom floating tab bar with `matchedGeometryEffect`.

## Sarvis/Models/
  TodoItem.swift          — `TodoItem` struct + `Importance` enum (low/medium/high/critical). Fields: `id`, `text`, `importance`, `isSensitive`, `type: InputType`, `createdAt`, `dueAt`, `isDone`, `notificationID`, `completedAt`.
  RawEntry.swift          — `RawEntry` struct. Fields: `id`, `text`, `importance`, `isSensitive`, `suggestedType: InputType?`, `dueAt`, `capturedAt`, `processed`, `processedAt`, `notificationID`. Custom `Decodable` for backward compat.
  InputType.swift         — `InputType` enum: task/note/idea/sensitive/other/diary/suggestion/shopping/quote. `.fileName` → per-type JSON filename under processed/.
  TodoStore.swift         — `@MainActor ObservableObject`. `TodoStore.shared`. Singleton managing all processed `TodoItem` items across typed files. Also the capture entry point (`capture(...)`).
  ScreenDefinition.swift  — `ScreenDefinition` + (contains or imports) `ElementSpec` data types for dynamic-UI screens.
  ElementSpec.swift       — `ElementSpec` struct (type key, bindingKey, config dict) for dynamic-UI element descriptors.
  AnyCodableValue.swift   — Type-erased Codable wrapper for `ScreenState` value bag.
  EmailItem.swift         — `EmailItem` struct + `EmailProvider` protocol + `EmailError` enum.
  EmailDigest.swift       — `EmailDigest` struct + `EmailAction` struct.

## Sarvis/Services/Storage/
  RawStore.swift          — `@MainActor` singleton. `RawStore.shared`, `entries: [RawEntry]` (@Published). Persists each entry as `Documents/raw/<uuid>.json`. `add(_:)`, `unprocessed()`, `markProcessed(_:)`, `setNotificationID(for:_:)`, `delete(_:)`.
  ProfileStore.swift      — `@MainActor` singleton. `ProfileStore.shared`, `profile: Profile` (@Published). `Profile` struct: `preferences: [String:String]`, `traits: [String]`, `updatedAt`. File: `Documents/processed/profile.json`. `save(_:)`, `merge(_ partial: [String: Any])`.
  DailyArtifactStore.swift — Value-type singleton. `DailyArtifactStore.shared`. Generic `read<T:Codable>(folder:date:)` / `write<T:Codable>(_:folder:date:)` against `Documents/processed/<folder>/<YYYY-MM-DD>.json`.
  InputProcessor.swift    — No-op middleware stub; not wired to any active pipeline.

## Sarvis/Services/LLM/
  LLMProvider.swift       — `LLMProvider` protocol (`send(messages:options:) async throws -> String`). `LLMMessage`, `LLMOptions` (model defaults `"claude-opus-4-7"`, maxTokens 1024), `LLMRole`, `LLMError`.
  AnthropicProvider.swift — `AnthropicProvider: LLMProvider`. Calls `https://api.anthropic.com/v1/messages`. No deps.
  LLMService.swift        — `@MainActor ObservableObject`. No shared singleton — instantiate per-caller. `send(_:)` (chat append), `ask(systemPrompt:prompt:)` and `ask(systemPrompt:prompt:options:)` (one-shot), `reload()`. Reads API key from Keychain account `"anthropic_api_key"`.
  ClassifierService.swift — `@MainActor` singleton. `ClassifierService.shared`. `classifyUnprocessed() async throws -> ClassifierReport`. Publishes `isRunning`, `lastRun: ClassifierDebugRecord?`. `ClassifierReport` struct, `ClassifierDebugRecord` struct, `ClassifierError` enum.
  PromptLibrary.swift     — Enum (namespace only). `PromptLibrary.body(for name: String, fallback: String) -> String`. Loads `<name>.md` from bundle, strips YAML header above first `---`.

## Sarvis/Services/News/
  NewsArticle.swift       — `NewsArticle` struct (title, description, url, source, publishedAt).
  NewsProvider.swift      — `NewsProvider` protocol (`fetchTopHeadlines(country:limit:) async throws -> [NewsArticle]`). `NewsError` enum.
  RssProvider.swift       — `RssProvider: NewsProvider`. Active default in `NewsService`. Google News RSS via `Foundation.XMLParser`. Topic read from `UserDefaults["sarvis_news_topic"]` (default `"top news"`). `RssProvider.topicDefaultsKey`, `RssProvider.defaultTopic`.
  GNewsProvider.swift     — Deprecated (v0.2.0). Still on disk; not referenced by `NewsService`.
  NewsCache.swift         — Value-type. `NewsCache`. `write(_:for:)`, `read(for:) -> [NewsArticle]?`. Path: `Documents/cache/news/<YYYY-MM-DD>.json`. Atomic write.
  NewsService.swift       — `@MainActor` singleton. `NewsService.shared`. `refreshToday(country:limit:) async throws -> [NewsArticle]`, `articlesForToday() -> [NewsArticle]?`.

## Sarvis/Services/Email/
  GoogleAuth.swift        — `@MainActor` singleton. `GoogleAuth.shared`. `authorize() async throws`, `accessToken() async throws -> String` (auto-refresh), `disconnect()`, `isConnected: Bool`, `email: String?`. Refresh token in Keychain account `"gmail_refresh_token"`. Client ID from `Info.plist["GoogleOAuthClientID"]`.
  GmailProvider.swift     — `GmailProvider: EmailProvider`. Two-call pattern: list IDs (`newer_than:1d`), fetch metadata. `fetchRecent(limit:since:) async throws -> [EmailItem]`. 401 auto-refreshes via `GoogleAuth`.
  EmailCache.swift        — Value-type. `EmailCache`. `saveToday(_:)`, `loadToday() -> [EmailItem]?`, `save(_:for:)`, `load(for:) -> [EmailItem]?`, `clearAll()`. Path: `Documents/cache/email/<YYYY-MM-DD>.json`.
  EmailDigestService.swift — `@MainActor` singleton. `EmailDigestService.shared`. `refreshToday(limit:) async throws -> EmailDigest` (fetch → cache → LLM classify → `DailyArtifactStore` write). `todaysDigest() -> EmailDigest?`. Persists at `Documents/processed/email/<date>.json`.

## Sarvis/Services/Jobs/
  MorningJob.swift        — `@MainActor` enum (namespace). `MorningJob.taskID = "com.shrey.sarvis.morning"`. `register()` (call in `App.init()`), `scheduleNext()` (targets next 7 AM). Handler: news refresh → LLM summary → artifact write → (if Gmail connected) email digest → `news.briefing` notification.
  QuoteJob.swift          — `@MainActor` enum. `QuoteJob.scheduleDailyPings()`. Schedules 9:30 AM + deterministic 14–18h ping via `UNCalendarNotificationTrigger`. IDs: `morningID`, `afternoonID`. Bodies baked at schedule time; category `quote.morning`.

## Sarvis/Services/
  NotificationService.swift — `NSObject` singleton. `NotificationService.shared`. `requestAuthorization()`, `registerCategories()` (registers TODO_REMINDER + task.reminder + news.briefing + quote.morning), `schedule(_ todo: TodoItem, at:) -> String`, `schedule(title:body:at:importance:) -> String`, `cancel(_:)`. Categories: `categoryTaskReminder`, `categoryNewsBriefing`, `categoryQuoteMorning`.
  KeychainService.swift   — Enum (namespace). `KeychainService.save(_:for:)`, `KeychainService.read(_:) -> String?`, `KeychainService.delete(_:)`. Service ID `"com.shrey.reminder.api"`.

## Sarvis/Services/Quotes/
  QuoteService.swift      — `@MainActor` singleton. `QuoteService.shared`. `Quote` struct (text, author?). `loadAll() -> [Quote]` (seed.json + Documents/processed/quotes.json, deduped), `random() -> Quote?`.

## Sarvis/UI/
  Theme.swift             — `Theme` enum with nested: `Spacing`, `Radius`, `Typography`, `Palette`, `LayeredBackground` View, `Haptics` (soft/light/success). `.themedCard(padding:cornerRadius:)` modifier.
  Toast.swift             — `ToastCenter.shared.show(_:)`. `.toastHost()` view modifier. `.dismissKeyboardToolbar()` view modifier.

## Sarvis/UI/Composer/
  ElementRegistry.swift   — `@MainActor` singleton. `ElementRegistry.shared`. `register(_ type: String, factory:)`, `make(_:state:) -> AnyView`, `registerBuiltIns()`. Factory type: `(ElementSpec, ScreenState) -> AnyView`.
  ScreenState.swift       — `@MainActor ObservableObject`. `values: [String: AnyCodableValue]`. `binding(for:default:) -> Binding<AnyCodableValue>`, `string(for:)`, `bool(for:)`, `reset()`.
  DynamicScreen.swift     — `DynamicScreen` SwiftUI view. Renders a `ScreenDefinition` by calling `ElementRegistry.shared.make` per spec.
  UnknownElementView.swift — Fallback view shown when no factory matches a type key.

## Sarvis/UI/Elements/Input/
  TextInput/              — `TextInputView`, `TextInputConfig`
  CalendarPicker/         — `CalendarPickerView`, `CalendarPickerConfig`
  TypeChip/               — `TypeChipView`
  ImportancePicker/       — `ImportancePickerView`
  ToggleRow/              — `ToggleRowView`, `ToggleRowConfig`
  ShoppingItem/           — `ShoppingItemView`, `ShoppingItemConfig`. `ShoppingUrgency` enum: today/nextVisit/thisWeek/someday.

## Sarvis/UI/Elements/Display/
  SummaryCard/            — `SummaryCardView`, `SummaryCardConfig`
  ActionButton/           — `ActionButtonView`, `ActionButtonConfig`
  TodoListRow/            — `TodoListRowView`
  NotesListRow/           — `NotesListRowView`
  ShoppingListRow/        — `ShoppingListRowView`
  DiaryEntry/             — `DiaryEntryView`
  QuoteCard/              — `QuoteCardView`
  NewsHeadline/           — `NewsHeadlineView`
  EmailRow/               — `EmailItemRow`, `EmailActionRow`

## Sarvis/Screens/
  InputView.swift         — Legacy capture screen (active in `RootView`). "Process with LLM" button calls `ClassifierService.shared.classifyUnprocessed()`. Surfaces real error string in toast.
  CaptureScreenDynamic.swift — Dynamic-UI parallel of capture screen (not active in RootView; uses `DynamicScreen`).
  TodayView.swift         — "Entries" tab. Lists unprocessed raws from `RawStore.shared.entries.filter { !$0.processed }`. Swipe-delete cancels pending notification, calls `RawStore.shared.delete`.
  ProcessedView.swift     — "Library" tab. Section chip picker: Today, Notes, Shopping, Diary, Ideas, Suggestions, Quotes, News, Email, Profile. Reads from `TodoStore.shared`, `DailyArtifactStore`, `EmailDigestService`.
  TodoSectionView.swift   — Tiled timeline inside Library → Todo. 4 tiles (Today/Tomorrow/Near Future/Everything Else). Swipe → done (`TodoStore.shared.toggleDone`). Tap → `TodoEditSheet`. Header icon → `CompletedTodosView`.
  SettingsView.swift      — API key input, news topic, Gmail connect/disconnect, model picker, Debug row.
  QuickCaptureSheet.swift — Modal sheet launched from `sarvis://capture` deep link. Focused TextField → `TodoStore.shared.capture(text:type:.note,...)` → toast.
  ClassifierDebugView.swift — Settings → Debug. Shows `ClassifierService.shared.lastRun` fields.

---

## SarvisWidget/
  SarvisWidgetBundle.swift — `@main SarvisWidgetBundle`. Registers `QuickCaptureWidget`.
  QuickCaptureWidget.swift — `QuickCaptureWidget: Widget`. `systemLarge` only. Configuration: `StaticConfiguration`.
  QuickCaptureProvider.swift — `Provider: TimelineProvider`. Returns a single `SimpleEntry`.
  QuickCaptureView.swift  — Widget view. Big text-field placeholder + Submit pill. Both `Link(destination: URL("sarvis://capture"))`.
  WidgetTheme.swift       — Duplicate theme tokens (warm palette, radii) scoped to widget extension.

---

## SarvisNotificationContent/
  NotificationViewController.swift — `UNNotificationContentExtension` entry point. Hosts `NotificationContentView` via `UIHostingController`.
  NotificationContentView.swift    — Routes to the correct template view based on `notification.request.content.categoryIdentifier`.
  TaskReminderView.swift  — Category `task.reminder`. Renders importance dot, serif title, body, due-time chip. Reads `userInfo["importance"]`, `userInfo["dueAt"]`.
  MorningBriefingView.swift — Category `news.briefing`. Date header + headline + bullet points. Reads `userInfo["headline"]`, `userInfo["bullets"]`.
  QuoteCardView.swift     — Category `quote.morning`. Serif quote body + attribution + soft gradient. Reads `userInfo["quote"]`, `userInfo["attribution"]`.
  ExtensionTheme.swift    — Standalone duplicate of host-app theme tokens for use within the extension target.
