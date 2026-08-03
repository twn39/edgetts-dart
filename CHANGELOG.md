## 0.4.0

- **Feat:** Added stream cancellation and lifecycle control via `Communicate.close()`, `Communicate.cancel()`, and `Communicate.isClosed`.
- **Refactor:** Optimized `HttpClient` lifecycle resource cleanup during WebSocket upgrade setup to prevent socket leaks.
- **Feat:** Added `receiveTimeout` stream enforcement on `Communicate` and optional `timeout` parameters to `listVoices()`, `VoicesManager.create()`, and `EdgeHttpClient.getWithRetry()`.
- **Test:** Added `@Tags(['network'])` to isolate live API integration tests in offline CI test runs.

## 0.3.1

- **Fix:** Synchronize audio offset compensation and text splitting logic with `edge-tts` 7.2.8.
  - Update audio offset calculation to use CBR audio bytes instead of cumulative metadata durations and padding, preventing timing drift in long texts.
  - Fix text splitting boundary calculations to safely handle edge cases where split boundary resolves to 0 or less, preventing potential crashes.
