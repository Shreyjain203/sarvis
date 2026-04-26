# News-fetcher worker — output

## NewsProvider API
`NewsProvider` is a protocol with one method:
```swift
func fetchTopHeadlines(country: String, limit: Int) async throws -> [NewsArticle]
```
Errors are typed as `NewsError`: `.noAPIKey`, `.badResponse`, `.decoding(Error)`.

## GNews integration
- Endpoint: `GET https://gnews.io/api/v4/top-headlines?lang=en&country=<country>&max=<limit>&apikey=<key>`
- API key read from Keychain account `gnews_api_key` via `KeychainService.read("gnews_api_key")`.
- `publishedAt` decoded with `ISO8601DateFormatter`.
- Free tier: 100 requests/day, no credit card required (gnews.io).

## Cache layout
Files stored at `<Documents>/cache/news/<YYYY-MM-DD>.json`.
- Each file is a JSON-encoded `[NewsArticle]` array.
- Writes are atomic: temp file + `FileManager.replaceItemAt`.

## Keychain account name
`gnews_api_key` — entered by the user in Settings → GNews API Key.

## Wiring scheduled refresh (Wave 2)
Call `await NewsService.shared.refreshToday()` from the morning-job worker (or a `BackgroundTasks` `BGProcessingTask`). The result is automatically cached; no additional plumbing needed. Inspect `NewsService.shared.lastError` for failures.

## Swapping providers
Conform any new struct to `NewsProvider` and inject it into `NewsService`:
```swift
let service = NewsService(provider: NewsAPIProvider())  // or any other conformer
```
The cache and all downstream consumers are provider-agnostic.
