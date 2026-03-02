# C++ stdio framing notes

Practical stdio message loop in C++:

1. Read header lines until blank line.
2. Parse `Content-Length`.
3. Read exactly that many bytes for JSON body.
4. Parse JSON and dispatch by `method`.
5. Serialize response and write:
   - `Content-Length: <N>\r\n\r\n`
   - `<json body>`

Important details:

- Strip trailing `\r` when reading lines.
- Flush stdout after each response.
- Ignore malformed messages instead of crashing.
