const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const RUN_ID = process.argv[2] || "pre-fix";
const ENDPOINT = "http://127.0.0.1:7282/ingest/963f32de-fcc8-4211-bb99-d1f1d6605248";
const SESSION_ID = "3b0766";

function collectUnderscoreMarkdownFiles(dirPath, files = []) {
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === ".git" || entry.name === "node_modules") {
      continue;
    }

    const absPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      collectUnderscoreMarkdownFiles(absPath, files);
      continue;
    }

    if (!entry.isFile() || !entry.name.endsWith(".md")) {
      continue;
    }

    const relPath = path.relative(ROOT, absPath);
    const hasUnderscoreSegment = relPath
      .split(path.sep)
      .some((segment) => segment.startsWith("_"));

    if (hasUnderscoreSegment) {
      files.push(relPath);
    }
  }
  return files;
}

function hasYamlFrontmatter(content) {
  return /^---\s*\n[\s\S]*?\n---\s*(\n|$)/.test(content);
}

function hasHtmlTag(content) {
  return /<\/?[A-Za-z][^>\n]*>/.test(content);
}

function hasNonAscii(content) {
  return /[^\x00-\x7F]/.test(content);
}

function readIfExists(absPath) {
  if (!fs.existsSync(absPath)) {
    return "";
  }
  return fs.readFileSync(absPath, "utf8");
}

function postDebugLog(payload) {
  // #region agent log
  fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Debug-Session-Id": "3b0766"
    },
    body: JSON.stringify(payload)
  }).catch(() => {});
  // #endregion
}

const rulePath = path.join(
  ROOT,
  ".cursor",
  "rules",
  "underscore-markdown-plain-text.mdc"
);
const ruleContent = readIfExists(rulePath);
const hasGlobsLine = /^globs:\s+.+/m.test(ruleContent);

// #region agent log
postDebugLog({
  sessionId: SESSION_ID,
  runId: RUN_ID,
  hypothesisId: "H1",
  location: "scripts/validate-underscore-markdown.js:72",
  message: "Rule file globs check",
  data: { rulePath: path.relative(ROOT, rulePath), hasGlobsLine },
  timestamp: Date.now()
});
// #endregion

const underscoreMarkdownFiles = collectUnderscoreMarkdownFiles(ROOT);

// #region agent log
postDebugLog({
  sessionId: SESSION_ID,
  runId: RUN_ID,
  hypothesisId: "H4",
  location: "scripts/validate-underscore-markdown.js:88",
  message: "Underscore markdown discovery",
  data: {
    count: underscoreMarkdownFiles.length,
    files: underscoreMarkdownFiles
  },
  timestamp: Date.now()
});
// #endregion

const frontmatterViolations = [];
const htmlViolations = [];
const nonAsciiViolations = [];

for (const relPath of underscoreMarkdownFiles) {
  const absPath = path.join(ROOT, relPath);
  const content = fs.readFileSync(absPath, "utf8");

  if (hasYamlFrontmatter(content)) {
    frontmatterViolations.push(relPath);
  }
  if (hasHtmlTag(content)) {
    htmlViolations.push(relPath);
  }
  if (hasNonAscii(content)) {
    nonAsciiViolations.push(relPath);
  }
}

// #region agent log
postDebugLog({
  sessionId: SESSION_ID,
  runId: RUN_ID,
  hypothesisId: "H2",
  location: "scripts/validate-underscore-markdown.js:118",
  message: "Frontmatter validation",
  data: {
    violations: frontmatterViolations,
    violationCount: frontmatterViolations.length
  },
  timestamp: Date.now()
});
// #endregion

// #region agent log
postDebugLog({
  sessionId: SESSION_ID,
  runId: RUN_ID,
  hypothesisId: "H3",
  location: "scripts/validate-underscore-markdown.js:130",
  message: "Plain markdown validation",
  data: {
    htmlViolations,
    nonAsciiViolations,
    htmlViolationCount: htmlViolations.length,
    nonAsciiViolationCount: nonAsciiViolations.length
  },
  timestamp: Date.now()
});
// #endregion

const langsmithFile = underscoreMarkdownFiles.find((filePath) =>
  /langsmith/i.test(filePath)
);
const langflowFile = underscoreMarkdownFiles.find((filePath) =>
  /langflow/i.test(filePath)
);
const langsmithHasLangGraph = langsmithFile
  ? /langgraph/i.test(fs.readFileSync(path.join(ROOT, langsmithFile), "utf8"))
  : false;
const langflowHasLangGraph = langflowFile
  ? /langgraph/i.test(fs.readFileSync(path.join(ROOT, langflowFile), "utf8"))
  : false;

// #region agent log
postDebugLog({
  sessionId: SESSION_ID,
  runId: RUN_ID,
  hypothesisId: "H5",
  location: "scripts/validate-underscore-markdown.js:157",
  message: "LangGraph context coverage",
  data: {
    langsmithFile: langsmithFile || null,
    langflowFile: langflowFile || null,
    langsmithHasLangGraph,
    langflowHasLangGraph
  },
  timestamp: Date.now()
});
// #endregion

const checksPassed =
  hasGlobsLine &&
  underscoreMarkdownFiles.length >= 2 &&
  frontmatterViolations.length === 0 &&
  htmlViolations.length === 0 &&
  nonAsciiViolations.length === 0 &&
  Boolean(langsmithFile) &&
  Boolean(langflowFile) &&
  langsmithHasLangGraph &&
  langflowHasLangGraph;

// #region agent log
postDebugLog({
  sessionId: SESSION_ID,
  runId: RUN_ID,
  hypothesisId: "H-SUMMARY",
  location: "scripts/validate-underscore-markdown.js:183",
  message: "Overall validation summary",
  data: { checksPassed },
  timestamp: Date.now()
});
// #endregion

