# Navigation docs — codemap + api-surface

Goal: future Claude sessions can answer "where does X live?" and "what's the signature of Y?" by reading two terse reference docs, instead of grepping/reading source. Both docs must be cheap to load (target ≤ ~250 lines combined). Skip anything STATE.md / docs/phase-1.md / docs/phase-2.md already covers.

- [x] Read STATE.md, docs/phase-1.md, docs/phase-2.md, Readme.md so you know what's already documented and avoid duplication
- [x] Create `docs/codemap.md` — a directory-tree style map for `Sarvis/`, `SarvisWidget/`, `SarvisNotificationContent/`. For each `.swift` file, one line of "what it does" + the key public symbols it declares (top-level types, singletons, key methods). Group by subdirectory. Use a compact format like:

      ```
      Sarvis/Services/Storage/
        RawStore.swift          — append-only store for raw captures (Documents/raw/<uuid>.json). `RawStore.shared`, `entries`, `add(_:)`, `setProcessed(_:)`, `setNotificationID(_:_:)`
      ```

  Don't paraphrase; copy actual symbol names. If a file is trivial (≤30 lines, single struct with obvious fields), one line suffices. Skip Resources/, Assets/, generated files, and `.dispatch/` artifacts.

- [x] Create `docs/api-surface.md` — public method signatures + 1-line behavior for the services future sessions are most likely to call into. Group by area:
  - **Storage** — `RawStore`, `TodoStore`, `ProfileStore`, `DailyArtifactStore`, `NewsCache`, `EmailCache`, `KeychainService`
  - **LLM** — `LLMService`, `AnthropicProvider`, `ClassifierService`, `PromptLibrary`
  - **News** — `NewsService`, `RssProvider` (note: `GNewsProvider` deprecated)
  - **Email** — `GoogleAuth`, `GmailProvider`, `EmailDigestService`
  - **Notifications + Jobs** — `NotificationService`, `MorningJob`, `QuoteJob`, `QuoteService`
  - **UI Composer** — `ScreenDefinition`, `ElementSpec`, `ElementRegistry`, `ScreenState`, `DynamicScreen`

  Format per entry: signature on one line + a sub-line of behavior. Example:

      ```
      RawStore.shared.add(_ entry: RawEntry)
        Persists entry as Documents/raw/<id>.json and pushes to `entries`.
      ```

  Only public surfaces. Skip private helpers, init details, Codable boilerplate. If a struct's surface is just `init + Codable conformance`, list it under "Models" with one line.

- [x] At the top of STATE.md, add (or extend) a "Reference docs" line in the intro block that points to `docs/codemap.md` and `docs/api-surface.md` and tells future Claude to read those FIRST before grepping. Use a targeted Edit, do not full-rewrite STATE.md
- [x] Sample-verify accuracy: pick 5 random entries from each new doc and `grep`/Read the source to confirm the symbol exists and behaves as described. Fix any drift you find. List the 10 spot-checks at the bottom of `.dispatch/tasks/nav-docs/output.md`
- [x] Write a short summary (line counts of both new docs, areas covered, anything you deliberately omitted, the spot-check results) to `.dispatch/tasks/nav-docs/output.md`
- [x] `touch .dispatch/tasks/nav-docs/ipc/.done`
