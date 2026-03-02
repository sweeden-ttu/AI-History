import json
import os
import time
import zipfile
from pathlib import Path

import gradio as gr

from generator import (
    analyze_files,
    anti_ghost_penalty,
    compile_server,
    emit_cpp_server_project,
    load_policy_state,
    retrieve_context,
    save_policy_state,
    select_strategy,
    update_reward,
)


CURRENT_DIR = Path(__file__).resolve().parent
KB_DIR = CURRENT_DIR / "kb"
TEMPLATE_DIR = CURRENT_DIR / "templates"
STATE_PATH = CURRENT_DIR / "state" / "policy_state.json"
OUT_DIR = CURRENT_DIR / "out"


def _normalize_uploaded_paths(files) -> list[str]:
    if not files:
        return []
    paths: list[str] = []
    for item in files:
        candidate = getattr(item, "name", item)
        if not candidate:
            continue
        path = Path(str(candidate))
        if path.is_file():
            paths.append(str(path))
    return paths


def analyze_action(files):
    file_paths = _normalize_uploaded_paths(files)
    if not file_paths:
        return {}, "No files uploaded.", gr.update(choices=[], value=None), None

    result = analyze_files(file_paths)
    ext_choices = sorted(result.extension_counts.keys())
    summary = (
        f"Files analyzed: {result.file_count}\n"
        f"Dominant extension: {result.dominant_extension}\n"
        f"Extensions: {', '.join(ext_choices)}"
    )
    return (
        result.to_dict(),
        summary,
        gr.update(choices=ext_choices, value=result.dominant_extension),
        result.to_dict(),
    )


def generate_and_optionally_compile(
    analysis_state,
    selected_extension,
    top_n_tokens,
    use_rl,
    ttl_lambda,
    vitamin,
    anti_ghost_enabled,
    do_compile,
):
    if not analysis_state:
        return "Run analysis first.", None, None

    analysis = dict(analysis_state)
    selected_ext = selected_extension or analysis.get("dominant_extension", "<none>")
    query = (
        f"lsp {selected_ext} initialize shutdown exit didOpen didChange completion "
        "Content-Length jsonrpc stdio C++"
    )
    retrieved = retrieve_context(
        kb_dir=KB_DIR,
        query=query,
        boost_terms=[selected_ext, "initialize", "completion", "content-length"],
        top_k=3,
    )

    strategy = "frequency"
    policy_state = load_policy_state(STATE_PATH)
    epsilon = min(1.0, max(0.0, float(vitamin)) * 0.1)
    if use_rl:
        strategy = select_strategy(policy_state, epsilon=epsilon)

    start = time.time()
    run_id = str(int(start))
    server_dir = OUT_DIR / run_id / "server"
    build_dir = OUT_DIR / run_id / "build"

    top_tokens = dict(list(analysis.get("token_counts_global", {}).items())[: int(top_n_tokens)])
    analysis["token_counts_global"] = top_tokens

    emit_info = emit_cpp_server_project(
        template_dir=TEMPLATE_DIR,
        output_server_dir=server_dir,
        analysis=analysis,
        selected_extension=selected_ext,
        retrieved_context=retrieved,
        strategy=strategy,
    )

    compile_log = "Generation complete.\n"
    artifact = None
    compile_ok = False
    smoke_ok = False
    binary_path = None
    if do_compile:
        compile_result = compile_server(server_dir=server_dir, build_dir=build_dir)
        compile_ok = bool(compile_result["ok"])
        compile_log += compile_result["log"]
        binary_path = compile_result["binary_path"]
        smoke_ok = compile_ok and binary_path is not None
    else:
        compile_log += "Compilation skipped."

    elapsed = time.time() - start
    anti_ghost_value = 0.0
    if anti_ghost_enabled:
        anti_ghost_value = anti_ghost_penalty(list(top_tokens.keys()))

    if use_rl:
        updated = update_reward(
            state=policy_state,
            strategy=strategy,
            compile_ok=compile_ok,
            smoke_ok=smoke_ok,
            elapsed_seconds=elapsed,
            ttl_lambda=float(ttl_lambda),
            vitamin=float(vitamin),
            anti_ghost=anti_ghost_value,
        )
        save_policy_state(STATE_PATH, updated)

    artifact_zip = OUT_DIR / run_id / "artifact.zip"
    artifact_zip.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(artifact_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in server_dir.rglob("*"):
            if path.is_file():
                zf.write(path, path.relative_to(server_dir.parent))
        if binary_path:
            bp = Path(binary_path)
            if bp.exists():
                zf.write(bp, Path("binary") / bp.name)
        zf.writestr("metadata.json", json.dumps({"emit": emit_info, "retrieved": retrieved}, indent=2))

    return compile_log, str(artifact_zip), json.dumps(retrieved, indent=2)


with gr.Blocks() as demo:
    gr.Markdown("# Gradio-driven LSP Generator (C++ + CMake)")
    gr.Markdown(
        "Upload files, compute extension/token stats, retrieve local KB context, generate a minimal C++ LSP server, and optionally compile it with CMake."
    )

    with gr.Row():
        files = gr.File(
            label="Upload files",
            file_count="multiple",
            type="filepath",
        )
        with gr.Column():
            analyze_btn = gr.Button("Analyze")
            generate_btn = gr.Button("Generate")
            generate_compile_btn = gr.Button("Generate & Compile")

    summary_md = gr.Markdown()
    analysis_json = gr.JSON(label="Analysis")
    extension_dropdown = gr.Dropdown(label="Selected extension", choices=[])

    with gr.Row():
        top_n_tokens = gr.Slider(label="Top-N tokens used for generation", minimum=20, maximum=300, value=120, step=10)
        use_rl = gr.Checkbox(label="Enable RL policy", value=True)
        anti_ghost_enabled = gr.Checkbox(label="Enable anti-ghost penalty", value=True)

    with gr.Row():
        ttl_lambda = gr.Slider(label="TTL penalty lambda", minimum=0.0, maximum=0.02, value=0.002, step=0.0005)
        vitamin = gr.Slider(label="Vitamin exploration boost", minimum=0.0, maximum=3.0, value=1.0, step=0.1)

    build_log = gr.Textbox(label="Build / generation log", lines=18)
    rag_output = gr.Code(label="Retrieved KB snippets (summary JSON)")
    artifact = gr.File(label="Download generated artifact (.zip)")
    analysis_state = gr.State(value=None)

    analyze_btn.click(
        fn=analyze_action,
        inputs=[files],
        outputs=[analysis_json, summary_md, extension_dropdown, analysis_state],
    )
    generate_btn.click(
        fn=lambda *args: generate_and_optionally_compile(*args, False),
        inputs=[
            analysis_state,
            extension_dropdown,
            top_n_tokens,
            use_rl,
            ttl_lambda,
            vitamin,
            anti_ghost_enabled,
        ],
        outputs=[build_log, artifact, rag_output],
    )
    generate_compile_btn.click(
        fn=lambda *args: generate_and_optionally_compile(*args, True),
        inputs=[
            analysis_state,
            extension_dropdown,
            top_n_tokens,
            use_rl,
            ttl_lambda,
            vitamin,
            anti_ghost_enabled,
        ],
        outputs=[build_log, artifact, rag_output],
    )


if __name__ == "__main__":
    port = int(os.getenv("PORT", "7860"))
    demo.launch(server_port=port)
