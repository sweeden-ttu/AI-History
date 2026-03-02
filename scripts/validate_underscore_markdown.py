import json
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
LOG_PATH = ROOT / ".cursor" / "debug-3b0766.log"
SESSION_ID = "3b0766"
RUN_ID = sys.argv[1] if len(sys.argv) > 1 else "pre-fix"


def log_event(hypothesis_id, location, message, data):
    payload = {
        "sessionId": SESSION_ID,
        "runId": RUN_ID,
        "hypothesisId": hypothesis_id,
        "location": location,
        "message": message,
        "data": data,
        "timestamp": int(__import__("time").time() * 1000),
    }
    # region agent log
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=True) + "\n")
    # endregion


def collect_underscore_markdown_files(base):
    files = []
    for path in base.rglob("*.md"):
        rel_parts = path.relative_to(base).parts
        if any(part.startswith("_") for part in rel_parts):
            files.append(path.relative_to(base).as_posix())
    return sorted(files)


def has_frontmatter(content):
    return bool(re.match(r"^---\s*\n[\s\S]*?\n---\s*(\n|$)", content))


def has_html(content):
    return bool(re.search(r"</?[A-Za-z][^>\n]*>", content))


def has_non_ascii(content):
    return any(ord(char) > 127 for char in content)


rule_path = ROOT / ".cursor" / "rules" / "underscore-markdown-plain-text.mdc"
rule_content = rule_path.read_text(encoding="utf-8") if rule_path.exists() else ""
has_globs_line = bool(re.search(r"^globs:\s+.+", rule_content, re.MULTILINE))

# region agent log
log_event(
    "H1",
    "scripts/validate_underscore_markdown.py:52",
    "Rule file globs check",
    {"rulePath": str(rule_path.relative_to(ROOT)), "hasGlobsLine": has_globs_line},
)
# endregion

underscore_markdown_files = collect_underscore_markdown_files(ROOT)

# region agent log
log_event(
    "H4",
    "scripts/validate_underscore_markdown.py:64",
    "Underscore markdown discovery",
    {"count": len(underscore_markdown_files), "files": underscore_markdown_files},
)
# endregion

frontmatter_violations = []
html_violations = []
non_ascii_violations = []

for rel_path in underscore_markdown_files:
    content = (ROOT / rel_path).read_text(encoding="utf-8")
    if has_frontmatter(content):
        frontmatter_violations.append(rel_path)
    if has_html(content):
        html_violations.append(rel_path)
    if has_non_ascii(content):
        non_ascii_violations.append(rel_path)

# region agent log
log_event(
    "H2",
    "scripts/validate_underscore_markdown.py:84",
    "Frontmatter validation",
    {
        "violationCount": len(frontmatter_violations),
        "violations": frontmatter_violations,
    },
)
# endregion

# region agent log
log_event(
    "H3",
    "scripts/validate_underscore_markdown.py:96",
    "Plain markdown validation",
    {
        "htmlViolationCount": len(html_violations),
        "htmlViolations": html_violations,
        "nonAsciiViolationCount": len(non_ascii_violations),
        "nonAsciiViolations": non_ascii_violations,
    },
)
# endregion

langsmith_file = next(
    (file for file in underscore_markdown_files if "langsmith" in file.lower()), None
)
langflow_file = next(
    (file for file in underscore_markdown_files if "langflow" in file.lower()), None
)
langsmith_has_langgraph = (
    bool(re.search(r"langgraph", (ROOT / langsmith_file).read_text(encoding="utf-8"), re.I))
    if langsmith_file
    else False
)
langflow_has_langgraph = (
    bool(re.search(r"langgraph", (ROOT / langflow_file).read_text(encoding="utf-8"), re.I))
    if langflow_file
    else False
)

# region agent log
log_event(
    "H5",
    "scripts/validate_underscore_markdown.py:126",
    "LangGraph context coverage",
    {
        "langsmithFile": langsmith_file,
        "langflowFile": langflow_file,
        "langsmithHasLangGraph": langsmith_has_langgraph,
        "langflowHasLangGraph": langflow_has_langgraph,
    },
)
# endregion

checks_passed = (
    has_globs_line
    and len(underscore_markdown_files) >= 2
    and len(frontmatter_violations) == 0
    and len(html_violations) == 0
    and len(non_ascii_violations) == 0
    and bool(langsmith_file)
    and bool(langflow_file)
    and langsmith_has_langgraph
    and langflow_has_langgraph
)

# region agent log
log_event(
    "H-SUMMARY",
    "scripts/validate_underscore_markdown.py:151",
    "Overall validation summary",
    {"checksPassed": checks_passed},
)
# endregion
