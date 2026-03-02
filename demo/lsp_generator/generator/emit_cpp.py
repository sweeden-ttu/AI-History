import json
from pathlib import Path


def _load_template(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _as_cpp_string_list(values: list[str]) -> str:
    escaped = [json.dumps(value) for value in values]
    return "{" + ", ".join(escaped) + "}"


def emit_cpp_server_project(
    template_dir: Path,
    output_server_dir: Path,
    analysis: dict,
    selected_extension: str,
    retrieved_context: list[dict],
    strategy: str,
) -> dict:
    output_server_dir.mkdir(parents=True, exist_ok=True)
    src_dir = output_server_dir / "src"
    src_dir.mkdir(parents=True, exist_ok=True)

    cmake_template = _load_template(template_dir / "CMakeLists.txt.in")
    cpp_template = _load_template(template_dir / "main.cpp.in")

    global_tokens = analysis.get("token_counts_global", {})
    top_tokens = list(global_tokens.items())[:200]
    completion_words = [
        token
        for token, _count in top_tokens
        if token.isidentifier() and len(token) <= 48
    ][:60]
    if not completion_words:
        completion_words = ["todo", "fixme", "exampleSymbol"]

    context_blob = "\n\n".join(
        f"[{item['name']}] (score={item['score']})\n{item['snippet']}"
        for item in retrieved_context
    )

    replacement_map = {
        "PROJECT_NAME__": "generated_lsp_server",
        "SERVER_NAME__": f"LSP Generator ({selected_extension})",
        "EXTENSION_": selected_extension,
        "_STRATEGY__": strategy,
        "_COMPLETION_JSON": _as_cpp_string_list(completion_words),
        "ANALYSIS.json": json.dumps(analysis, indent=2),
        "RAG\/CONTEXT/\'`": context_blob,
    }

    for key, value in replacement_map.items():
        cmake_template = cmake_template.replace(key, value)
        cpp_template = cpp_template.replace(key, value)

    (output_server_dir / "CMakeLists.txt").write_text(cmake_template, encoding="utf-8")
    (src_dir / "main.cpp").write_text(cpp_template, encoding="utf-8")
    (output_server_dir / "README.md").write_text(
        (
            "# Generated LSP Server\n\n"
            "Build with:\n\n"
            "```bash\n"
            "cmake -S . -B build\n"
            "cmake --build build --parallel\n"
            "```\n"
        ),
        encoding="utf-8",
    )

    return {
        "server_dir": str(output_server_dir),
        "token_count_embedded": len(completion_words),
        "strategy": strategy,
    }
