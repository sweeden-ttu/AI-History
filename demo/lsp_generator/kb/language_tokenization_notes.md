# Language tokenization notes

Simple cross-language tokenization can be done with regex:

- identifiers: `[A-Za-z_][A-Za-z0-9_]*`
- numbers: `\d+`
- fallback symbols: non-whitespace single chars

For generated completion candidates:

- prefer frequent identifiers
- de-prioritize very long and repeated tokens
- keep ordering deterministic
