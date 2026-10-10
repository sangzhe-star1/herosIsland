#!/usr/bin/env python3
"""Migrate a copied game save in an isolated Godot user:// sandbox.

    python3 tests/audit_garden_save.py --save /path/to/save_game.json

The original file is read-only. The report and normalized copy go to a fresh
temporary directory unless --output-dir is supplied.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True

from qa_run import QAError, QASession, find_godot


PROJECT = Path(__file__).resolve().parents[1]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--save", required=True, type=Path, help="Copied save_game.json from the device")
    parser.add_argument("--godot", help="Godot executable (or set GODOT)")
    parser.add_argument("--output-dir", type=Path, help="Directory for the report and normalized save copy")
    parser.add_argument("--timeout", type=float, default=120)
    options = parser.parse_args()

    source = options.save.expanduser().resolve()
    if not source.is_file():
        parser.error(f"save file does not exist: {source}")
    output_dir = options.output_dir.expanduser().resolve() if options.output_dir else Path(
        tempfile.mkdtemp(prefix="heroes-save-audit-")
    ).resolve()
    if output_dir == PROJECT or PROJECT in output_dir.parents:
        parser.error("output-dir must be outside the project so personal save data cannot enter Git")
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / "migration_report.json"
    normalized_path = output_dir / "normalized_save.json"
    if report_path.exists() or normalized_path.exists():
        parser.error("output-dir already contains audit output; choose a fresh directory")

    original_digest = sha256(source)
    try:
        godot = find_godot(options.godot)
    except QAError as error:
        print(f"Save migration audit failed: {error}", file=sys.stderr)
        return error.exit_code
    report = None
    failure: Exception | None = None
    try:
        with QASession(PROJECT, godot, "ipad-save-audit", options.timeout) as session:
            session.import_project(timeout=options.timeout)
            session.run_godot(
                [
                    "--headless",
                    "res://tests/SaveMigrationAudit.tscn",
                    "--",
                    "--input-save",
                    str(source),
                    "--output-dir",
                    str(output_dir),
                ],
                label="save-migration-audit",
                expect="SAVE MIGRATION AUDIT COMPLETED",
            )
        if not report_path.is_file() or not normalized_path.is_file():
            raise QAError("Godot completed without producing both audit artifacts.")
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (QAError, OSError, json.JSONDecodeError) as error:
        failure = error
    finally:
        try:
            source_unchanged = source.is_file() and sha256(source) == original_digest
        except OSError:
            source_unchanged = False
    if not source_unchanged:
        print("Source SHA-256 changed or the source became unavailable during audit.", file=sys.stderr)
        return 3
    if failure is not None:
        print(f"Source remains unchanged (SHA-256 {original_digest}): {source}")
        if isinstance(failure, QAError):
            print(f"Save migration audit failed: {failure}", file=sys.stderr)
            return failure.exit_code
        print(f"Save migration audit setup failed: {failure}", file=sys.stderr)
        return 2
    if report is None:
        print("Save migration audit produced no report.", file=sys.stderr)
        return 2
    try:
        print(f"Source unchanged (SHA-256 {original_digest}): {source}")
        print(f"Report: {report_path}")
        print(f"Normalized isolated copy: {normalized_path}")
        print(json.dumps(report.get("checks", {}), ensure_ascii=False, indent=2))
        print(f"Basic checks passed: {report.get('basic_checks_passed', False)}")
        if report.get("human_review_required", True):
            print("Human review required: inspect changed/lost farm keys before using the normalized copy.")
        if not report.get("basic_checks_passed", False):
            print("One or more preservation checks failed; do not use the normalized copy until reviewed.")
        return 0
    except (OSError, json.JSONDecodeError) as error:
        print(f"Save migration audit setup failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
