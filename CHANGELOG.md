## 0.3.1

- **Fix:** Synchronize audio offset compensation and text splitting logic with `edge-tts` 7.2.8.
  - Update audio offset calculation to use CBR audio bytes instead of cumulative metadata durations and padding, preventing timing drift in long texts.
  - Fix text splitting boundary calculations to safely handle edge cases where split boundary resolves to 0 or less, preventing potential crashes.
