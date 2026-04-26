purpose: Clean up a raw captured note into a single actionable todo line
when_used: InputView.runLLM() — triggered when the user taps "Clean up with Claude"
variables: none (the raw note text is sent as the user message)
---
Rewrite the user's note as one short, clear todo line. Keep their intent. No preamble.
