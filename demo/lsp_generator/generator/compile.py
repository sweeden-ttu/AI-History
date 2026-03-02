import shutil
import subprocess
from pathlib import Path


def _run_cmd(args: list[str], cwd: Path) -> tuple[int, str]:
    process = subprocess.run(
        args,
        cwd=str(cwd),
        capture_output=True,
        text=True,
        check=False,
    )
    log = f"$ {' '.join(args)}\n{process.stdout}\n{process.stderr}\n"
    return process.returncode, log


def compile_server(server_dir: Path, build_dir: Path) -> dict:
    cmake_path = shutil.which("cmake")
    if not cmake_path:
        return {"ok": False, "log": "cmake not found on PATH", "binary_path": None}

    server_dir = server_dir.resolve()
    build_dir = build_dir.resolve()
    build_dir.mkdir(parents=True, exist_ok=True)
    rc1, log1 = _run_cmd([cmake_path, "-S", str(server_dir), "-B", str(build_dir)], cwd=server_dir)
    if rc1 != 0:
        return {"ok": False, "log": log1, "binary_path": None}

    rc2, log2 = _run_cmd([cmake_path, "--build", str(build_dir), "--parallel"], cwd=server_dir)
    full_log = log1 + "\n" + log2
    if rc2 != 0:
        return {"ok": False, "log": full_log, "binary_path": None}

    candidate_names = ["generated_lsp_server", "generated_lsp_server.exe"]
    for name in candidate_names:
        direct = build_dir / name
        if direct.exists():
            return {"ok": True, "log": full_log, "binary_path": str(direct)}

    for path in build_dir.rglob("*"):
        if path.is_file() and path.name in candidate_names:
            return {"ok": True, "log": full_log, "binary_path": str(path)}

    return {"ok": True, "log": full_log, "binary_path": None}
