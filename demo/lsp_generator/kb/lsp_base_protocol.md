# LSP Base Protocol

Language Server Protocol uses JSON-RPC over a byte stream (usually stdio).

- Headers are ASCII text, one per line.
- `Content-Length` header is required and indicates the byte size of the JSON payload.
- Headers end with `\r\n\r\n`.
- Message body is UTF-8 JSON.

Minimal request shape:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
```

Minimal response shape:

```json
{"jsonrpc":"2.0","id":1,"result":{}}
```
