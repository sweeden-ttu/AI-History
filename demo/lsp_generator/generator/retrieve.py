from pathlib import Path
import re


WORD_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def _tokenize(text: str) -> set[str]:
    return {token.lower() for token in WORD_PATTERN.findall(text)}


def _load_kb_documents(kb_dir: Path) -> list[dict]:
    docs: list[dict] = []
    for path in sorted(kb_dir.glob("*.md")):
        content = path.read_text(encoding="utf-8", errors="ignore")
        docs.append(
            {
                "name": path.name,
                "content": content,
                "tokens": _tokenize(content),
            }
        )
    return docs


def retrieve_context(
    kb_dir: Path, query: str, boost_terms: list[str] | None = None, top_k: int = 3
) -> list[dict]:
    boosts = {term.lower() for term in (boost_terms or [])}
    query_tokens = _tokenize(query)
    docs = _load_kb_documents(kb_dir)
    scored: list[tuple[float, dict]] = []

    for doc in docs:
        overlap = len(query_tokens.intersection(doc["tokens"]))
        boost_score = sum(1 for term in boosts if term in doc["tokens"])
        score = float(overlap + 2 * boost_score)
        if score <= 0:
            continue
        scored.append((score, doc))

    ranked = sorted(scored, key=lambda item: (-item[0], item[1]["name"]))[:top_k]
    results: list[dict] = []
    for score, doc in ranked:
        snippet = doc["content"].strip()
        if len(snippet) > 1800:
            snippet = snippet[:1800] + "\n...\n"
        results.append({"name": doc["name"], "score": score, "snippet": snippet})
    return results
