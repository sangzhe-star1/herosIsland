#!/usr/bin/env python3
"""Run a Godot probe in a copied project with its own user:// directory.

    python3 tests/qa_run.py --name garden --expect "GARDEN TOUCH PROBE PASSED" \
        -- --rendering-driver opengl3 res://tests/GardenTouchProbe.tscn

The copy and logs remain in the printed temporary directory. This runner needs
Python 3 and a Unix host (macOS or Linux); it does not need GNU ``timeout``.
QASession also supports multiple serial runs against one snapshot for a suite.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import fcntl
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from typing import Mapping, Sequence


EXCLUDED_NAMES = {
    ".git", ".godot", "__pycache__", "tmp", "build", "_to_delete",
}
LOCK_PATH = Path("/tmp/heroes-island-godot-qa.lock")
SCRIPT_ERRORS = re.compile(r"SCRIPT ERROR|Parse Error|Parser Error")
ENGINE_ERRORS = re.compile(r"^\s*ERROR:", re.MULTILINE)
# Engine lines that are not a failure of the thing under test. Godot prints
# both of these at exit when a tween, timer or texture is still referenced
# the instant the tree is torn down; they were in every green run of the
# July baseline, and on a clean Linux box they stopped the WHOLE suite at
# SmokeTest -- after SmokeTest had printed PASSED. Anything else that says
# ERROR: still fails the run.
HARMLESS_EXIT_ERRORS = re.compile(
    r"^\s*ERROR: (?:\d+ resources still in use at exit"
    r"|\d+ RID allocations of type .* were leaked at exit)",
    re.MULTILINE)


def engine_errors(output: str) -> bool:
    """True when the log has an ERROR: line that is not a known exit notice."""
    for hit in ENGINE_ERRORS.finditer(output):
        line_end = output.find("\n", hit.start())
        line = output[hit.start():line_end if line_end >= 0 else None]
        if not HARMLESS_EXIT_ERRORS.match(line):
            return True
    return False
GODOT_NAME = re.compile(r"godot(?:4)?(?:[._-].*)?", re.IGNORECASE)
APPLICATION_KEYS = {
    "config/name", "config/use_custom_user_dir", "config/custom_user_dir_name",
}


class QAError(RuntimeError):
    def __init__(self, message: str, exit_code: int = 1):
        super().__init__(message)
        self.exit_code = exit_code


def application_settings(text: str) -> dict[str, str]:
    """Read raw assignment values from exactly one [application] section."""
    settings: dict[str, str] = {}
    active = False
    sections = 0
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            active = stripped == "[application]"
            if active:
                sections += 1
            continue
        if active and "=" in stripped and not stripped.startswith(";"):
            key, value = stripped.split("=", 1)
            key = key.strip()
            if key in settings:
                raise QAError(f"Duplicate application setting: {key}")
            settings[key] = value.strip()
    if sections != 1:
        raise QAError("project.godot must contain one [application] section")
    return settings


def isolated_config(text: str, identifier: str) -> str:
    """Replace only the user-directory settings inside [application]."""
    application_settings(text)
    lines: list[str] = []
    active = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            active = stripped == "[application]"
            lines.append(line)
            if active:
                lines.extend([
                    f'config/name="{identifier}"',
                    "config/use_custom_user_dir=true",
                    f'config/custom_user_dir_name="{identifier}"',
                ])
            continue
        key = stripped.split("=", 1)[0].strip()
        if active and key in APPLICATION_KEYS:
            continue
        lines.append(line)
    return "\n".join(lines) + "\n"


def snapshot_project(source: Path, name: str) -> Path:
    """Copy the current files, including uncommitted and untracked resources."""
    source = Path(source).resolve()
    project = source / "project.godot"
    if not project.is_file():
        raise QAError(f"No project.godot in {source}", 2)
    # Validate before creating a copy. .gdignore is deliberately not excluded:
    # it controls Godot imports, not whether a resource belongs to the snapshot.
    application_settings(project.read_text(encoding="utf-8"))
    slug = re.sub(r"[^a-z0-9_-]+", "-", name.lower()).strip("-_")[:40] or "run"
    qa_root = Path(tempfile.mkdtemp(prefix=f"heroes-qa-{slug}-")).resolve()
    print(f"QA project: {qa_root}", flush=True)
    if source == qa_root or source in qa_root.parents:
        raise QAError("The temporary directory must be outside the source project.", 2)
    shutil.copytree(
        source, qa_root, dirs_exist_ok=True,
        ignore=shutil.ignore_patterns(*EXCLUDED_NAMES),
        # Dereference file links so engine imports cannot write through a link
        # to the user's checkout. No cache directory is linked into the copy.
        symlinks=False,
    )
    copied_project = qa_root / "project.godot"
    copied_project.write_text(
        isolated_config(copied_project.read_text(encoding="utf-8"), qa_root.name),
        encoding="utf-8",
    )
    (qa_root / "qa_logs").mkdir(exist_ok=True)
    (qa_root / "qa_shots").mkdir(exist_ok=True)
    return qa_root


def find_godot(explicit: str | None = None) -> Path:
    requested = explicit or os.environ.get("GODOT")
    if requested:
        candidate = Path(shutil.which(requested) or requested).expanduser()
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate.resolve()
        raise QAError(f"Godot executable is not available: {requested}", 2)
    candidates = [
        Path("/Applications/Godot.app/Contents/MacOS/Godot"),
        Path.home() / "Applications/Godot.app/Contents/MacOS/Godot",
    ]
    for command in ("godot4", "godot"):
        found = shutil.which(command)
        if found:
            candidates.append(Path(found))
    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate.resolve()
    raise QAError("Could not find Godot; use --godot /path/to/Godot or GODOT.", 2)


def godot_processes() -> list[str]:
    """Use executable names, including executables in AppTranslocation paths."""
    inventory = subprocess.run(
        ["ps", "-axo", "pid=,comm="], capture_output=True, text=True,
        check=True, timeout=5,
    )
    found = []
    for line in inventory.stdout.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) == 2:
            executable = fields[1].removesuffix(" (deleted)")
            if GODOT_NAME.fullmatch(Path(executable).name):
                found.append(f"{fields[0]} ({executable})")
    return found


def require_no_godot() -> None:
    existing = godot_processes()
    if existing:
        raise QAError("Godot is already running: " + ", ".join(existing), 2)


class ExclusiveGodotLock:
    """Keep the same inode and hold the lock until every suite run is done."""

    def __init__(self, path: Path = LOCK_PATH):
        self.path = Path(path)
        self._file = None

    def __enter__(self):
        self._file = self.path.open("a+", encoding="utf-8")
        try:
            fcntl.flock(self._file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            self._file.close()
            self._file = None
            raise QAError("Another QA runner owns the Godot window.", 2) from None
        return self

    def __exit__(self, exc_type, exc, traceback):
        if self._file is not None:
            fcntl.flock(self._file.fileno(), fcntl.LOCK_UN)
            self._file.close()
            self._file = None
        # Never unlink the lock file: a waiting process must see the same inode.


@dataclass
class RunResult:
    returncode: int
    elapsed: float
    log_path: Path
    timed_out: bool = False


def terminate_own_group(process: subprocess.Popen) -> None:
    """Only terminate the session this runner created, then reap its parent."""
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    deadline = time.monotonic() + 3
    # The parent may exit before one of its children. Reap the parent while
    # checking the whole group, so a child cannot escape the timeout cleanup.
    while True:
        process.poll()
        try:
            os.killpg(process.pid, 0)
        except ProcessLookupError:
            break
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            break
        time.sleep(min(remaining, 0.05))
    process.wait()


def run_process(
    command: Sequence[str], log_path: Path, timeout: float,
    env: Mapping[str, str] | None = None,
) -> RunResult:
    """Run without a shell; enforce wall time and clean up on interruption."""
    if not math.isfinite(timeout) or timeout <= 0:
        raise QAError("Timeout must be positive and finite.", 2)
    log_path = Path(log_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    process = None
    timed_out = False
    with log_path.open("w", encoding="utf-8") as output:
        try:
            process = subprocess.Popen(
                list(command), stdout=output, stderr=subprocess.STDOUT,
                env=env, start_new_session=True,
            )
            print(f"QA process {process.pid}; log: {log_path}", flush=True)
            try:
                returncode = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                terminate_own_group(process)
                returncode = 124
        except BaseException:
            if process is not None:
                terminate_own_group(process)
            raise
    result = RunResult(returncode, time.monotonic() - started, log_path, timed_out)
    print(f"{log_path.stem}: exit={returncode}, elapsed={result.elapsed:.1f}s", flush=True)
    return result


def check_result(result: RunResult, expect: str | None = None) -> None:
    output = result.log_path.read_text(encoding="utf-8", errors="replace")
    if result.timed_out:
        raise QAError(f"Wall-clock timeout; see {result.log_path}", 124)
    if result.returncode != 0:
        raise QAError(f"Godot exited with {result.returncode}; see {result.log_path}")
    if SCRIPT_ERRORS.search(output):
        raise QAError(f"Script error found; see {result.log_path}")
    if engine_errors(output):
        raise QAError(f"Godot error found; see {result.log_path}")
    if expect is not None and expect not in output:
        raise QAError(f"Missing expected marker {expect!r}; see {result.log_path}")
    if expect is not None and expect.endswith("PASSED"):
        failed_marker = expect.removesuffix("PASSED") + "FAILED"
        if failed_marker in output:
            raise QAError(f"Failure marker {failed_marker!r}; see {result.log_path}")


def validate_godot_args(args: Sequence[str]) -> None:
    # Later options can override a --path that appeared earlier. A main pack
    # can also replace the project settings and restore the real save root.
    forbidden = {"--path", "--main-pack", "--upwards", "--project-manager", "-p",
                 "--gdscript-docs", "--remote-fs"}
    for argument in args:
        if argument.split("=", 1)[0] in forbidden or argument.endswith("project.godot"):
            raise QAError(f"{argument!r} would bypass the isolated project.", 2)


class QASession:
    """A single snapshot, unique save root and lock for one probe or a suite."""

    def __init__(
        self, project: Path, godot: Path, name: str = "run", timeout: float = 120,
        audio_driver: str = "Dummy",
    ):
        self.source = Path(project).resolve()
        self.godot = Path(godot).resolve()
        self.name = name
        self.timeout = timeout
        self.audio_driver = audio_driver
        self.qa_root: Path | None = None
        self._lock = ExclusiveGodotLock()
        self._active = False

    def __enter__(self):
        self._lock.__enter__()
        try:
            require_no_godot()
            self.qa_root = snapshot_project(self.source, self.name)
            self._active = True
            self._verify_isolation()
        except BaseException:
            self._active = False
            self._lock.__exit__(None, None, None)
            raise
        return self

    def __exit__(self, exc_type, exc, traceback):
        self._active = False
        self._lock.__exit__(exc_type, exc, traceback)

    def _verify_isolation(self) -> None:
        if not self._active or self.qa_root is None or self.qa_root == self.source:
            raise QAError("QA runs require an active isolated session.", 2)
        project = self.qa_root / "project.godot"
        if project.is_symlink():
            raise QAError("The isolated project configuration cannot be a symlink.", 2)
        settings = application_settings(project.read_text(encoding="utf-8"))
        identifier = f'"{self.qa_root.name}"'
        expected = {
            "config/name": identifier,
            "config/use_custom_user_dir": "true",
            "config/custom_user_dir_name": identifier,
        }
        if any(settings.get(key) != value for key, value in expected.items()):
            raise QAError("The QA application/save-directory settings changed.", 2)

    def run_godot(
        self, args: Sequence[str], label: str = "run", timeout: float | None = None,
        expect: str | None = None, env: Mapping[str, str] | None = None,
        prefix: Sequence[str] = (),
    ) -> RunResult:
        validate_godot_args(args)
        self._verify_isolation()
        require_no_godot()
        if not re.fullmatch(r"[A-Za-z0-9_-]+", label):
            raise QAError("Log labels may contain only letters, numbers, - and _.", 2)
        environment = os.environ.copy()
        if env is not None:
            environment.update(env)
        environment["HEROES_QA_PROJECT"] = str(self.qa_root)
        command = list(prefix) + [
            str(self.godot), "--path", str(self.qa_root),
            "--audio-driver", self.audio_driver,
        ] + list(args)
        result = run_process(
            command, self.qa_root / "qa_logs" / f"{label}.log",
            self.timeout if timeout is None else timeout, environment,
        )
        check_result(result, expect)
        return result

    def import_project(self, timeout: float = 120) -> RunResult:
        # Import only the isolated copy; no fallback can silently swallow a
        # broken class cache or bypass the timeout/serial-process gate.
        result = self.run_godot(
            ["--headless", "--editor", "--import", "--quit"],
            label="import", timeout=timeout,
        )
        if engine_errors(result.log_path.read_text(errors="replace")):
            raise QAError(f"Resource import error; see {result.log_path}")
        return result


def load_suite(path: Path) -> list[dict]:
    """Keep the original probe order and validate every entry before launch."""
    try:
        entries = json.loads(path.read_text(encoding="utf-8"))["probes"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise QAError(f"Cannot read smoke suite {path}: {error}", 2) from error
    if not isinstance(entries, list) or not entries:
        raise QAError("The smoke suite must contain probes.", 2)
    names = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise QAError("Every suite probe must be an object.", 2)
        name = entry.get("name")
        args = entry.get("args")
        expect = entry.get("expect")
        timeout = entry.get("timeout")
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", name) or name in names:
            raise QAError(f"Invalid or duplicate suite probe name: {name!r}", 2)
        if not isinstance(args, list) or not args or not all(isinstance(arg, str) for arg in args):
            raise QAError(f"Invalid arguments for suite probe {name}.", 2)
        validate_godot_args(args)
        if not isinstance(expect, str) or not expect.strip():
            raise QAError(f"Missing success marker for suite probe {name}.", 2)
        if not isinstance(timeout, (int, float)) or isinstance(timeout, bool) or not math.isfinite(timeout) or timeout <= 0:
            raise QAError(f"Invalid timeout for suite probe {name}.", 2)
        if not isinstance(entry.get("window"), bool):
            raise QAError(f"Missing window requirement for suite probe {name}.", 2)
        names.add(name)
    return entries


def run_suite(session: QASession, entries: Sequence[dict], timeout: float | None = None) -> None:
    """Run one snapshot serially, preserving the save shared by the old suite."""
    needs_xvfb = sys.platform.startswith("linux") and not os.environ.get("DISPLAY")
    xvfb = shutil.which("xvfb-run") if needs_xvfb else None
    passed = 0
    skipped = []
    for entry in entries:
        name = entry["name"]
        prefix = []
        environment = {}
        if entry["window"] and needs_xvfb:
            if xvfb is None:
                skipped.append(name)
                print(f"SKIPPED {name}: no display or xvfb-run", flush=True)
                continue
            prefix = [xvfb, "-a", "-s", "-screen 0 1920x1200x24"]
            environment["LIBGL_ALWAYS_SOFTWARE"] = "1"
        print(f"Running {name}...", flush=True)
        session.run_godot(
            entry["args"], label=name,
            timeout=entry["timeout"] if timeout is None else timeout,
            expect=entry["expect"], env=environment, prefix=prefix,
        )
        passed += 1
    print(f"Suite finished: {passed} passed, {len(skipped)} skipped", flush=True)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Godot executable (or set GODOT)")
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--name", default="run", help="Label for the temporary project")
    parser.add_argument("--timeout", type=float, help="Override each run's wall time (single scene default: 120s)")
    parser.add_argument("--audio-driver", default="Dummy")
    parser.add_argument("--expect", help="Required success marker in the scene log")
    parser.add_argument("--suite", type=Path, help="Run a JSON probe suite in the same isolated save")
    parser.add_argument("args", nargs=argparse.REMAINDER, help="Godot arguments after --")
    options = parser.parse_args(argv)
    args = options.args[1:] if options.args[:1] == ["--"] else options.args
    if bool(args) == bool(options.suite):
        parser.error("Provide either --suite or a scene and Godot options after --")
    if options.suite and options.expect is not None:
        parser.error("--suite reads its success markers from the manifest")
    if options.timeout is not None and (not math.isfinite(options.timeout) or options.timeout <= 0):
        parser.error("--timeout must be positive and finite")
    if options.expect is not None and not options.expect.strip():
        parser.error("--expect cannot be empty")

    def interrupted(signum, frame):
        raise KeyboardInterrupt

    previous_handlers = {}
    for signum in (signal.SIGTERM, signal.SIGHUP):
        previous_handlers[signum] = signal.signal(signum, interrupted)
    try:
        validate_godot_args(args)
        entries = load_suite(options.suite) if options.suite else None
        godot = find_godot(options.godot)
        with QASession(
            options.project, godot, options.name, options.timeout or 120, options.audio_driver,
        ) as session:
            session.import_project(timeout=options.timeout or 120)
            if entries is not None:
                run_suite(session, entries, timeout=options.timeout)
            else:
                result = session.run_godot(args, expect=options.expect)
                print("".join(result.log_path.read_text(errors="replace").splitlines(keepends=True)[-35:]))
        return 0
    except KeyboardInterrupt:
        print("QA interrupted; its launched process group was stopped.", file=sys.stderr)
        return 130
    except QAError as error:
        print(f"QA refused/failed: {error}", file=sys.stderr)
        return error.exit_code
    except (OSError, subprocess.SubprocessError) as error:
        print(f"QA setup/process error: {error}", file=sys.stderr)
        return 2
    finally:
        for signum, handler in previous_handlers.items():
            signal.signal(signum, handler)


if __name__ == "__main__":
    sys.exit(main())
