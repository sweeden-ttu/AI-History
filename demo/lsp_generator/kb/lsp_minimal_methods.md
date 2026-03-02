# LSP Minimal Methods

Required baseline server behavior for a minimal implementation:

- `initialize` (request): return capabilities and server info.
- `shutdown` (request): return `null`.
- `exit` (notification): terminate process.
- `textDocument/didOpen`: cache opened document.
- `textDocument/didChange`: update cached document text.
- `textDocument/completion`: return completion list.

Typical completion result:

```json
{
  "isIncomplete": false,
  "items": [{"label": "example", "kind": 6}]
}
```
