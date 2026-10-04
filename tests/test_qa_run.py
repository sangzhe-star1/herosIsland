"""Runner checks use temporary files and Python subprocesses, never Godot."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import qa_run


PROJECT = '''config_version=5
[application]
config/name="Production"
run/main_scene="res://Main.tscn"
config/use_custom_user_dir=false
config/custom_user_dir_name="Production"
[rendering]
config/name="leave this value"
renderer/rendering_method="gl_compatibility"
'''


class QARunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="heroes-qa-runner-check-")
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)

    def result(self, output, returncode=0, timed_out=False):
        log = self.root / "run.log"
        log.write_text(output)
        return qa_run.RunResult(returncode, 0.01, log, timed_out)

    def test_config_rewrites_only_application(self):
        changed = qa_run.isolated_config(PROJECT, "qa-unique")
        settings = qa_run.application_settings(changed)
        self.assertEqual(settings["config/name"], '"qa-unique"')
        self.assertEqual(settings["config/custom_user_dir_name"], '"qa-unique"')
        self.assertEqual(settings["config/use_custom_user_dir"], "true")
        self.assertIn('config/name="leave this value"', changed)
        self.assertIn('run/main_scene="res://Main.tscn"', changed)

    def test_duplicate_application_sections_or_keys_are_rejected(self):
        for text in [PROJECT + "\n[application]\n", PROJECT.replace(
                'config/name="Production"', 'config/name="Production"\nconfig/name="Again"')]:
            with self.subTest(text=text), self.assertRaises(qa_run.QAError):
                qa_run.application_settings(text)

    def test_snapshot_keeps_working_files_and_dereferences_links(self):
        source = self.root / "source"
        source.mkdir()
        (source / "project.godot").write_text(PROJECT)
        (source / "untracked.gd").write_text("extends Node\n")
        (source / ".godot").mkdir()
        (source / ".godot" / "stale").write_text("cache")
        (source / "assets").mkdir()
        (source / "assets" / ".gdignore").touch()
        target = self.root / "external.gd"
        target.write_text("external content")
        (source / "linked.gd").symlink_to(target)
        snapshot = qa_run.snapshot_project(source, "check")
        self.addCleanup(qa_run.shutil.rmtree, snapshot)
        self.assertNotEqual(snapshot, source)
        self.assertEqual((source / "project.godot").read_text(), PROJECT)
        self.assertTrue((snapshot / "untracked.gd").exists())
        self.assertTrue((snapshot / "assets" / ".gdignore").exists())
        self.assertFalse((snapshot / ".godot").exists())
        self.assertFalse((snapshot / "linked.gd").is_symlink())
        self.assertEqual((snapshot / "linked.gd").read_text(), "external content")
        self.assertEqual(qa_run.application_settings((snapshot / "project.godot").read_text())[
            "config/custom_user_dir_name"], '"' + snapshot.name + '"')

    def test_project_override_flags_are_rejected(self):
        for args in [["--path", "/source"], ["--path=/source"], ["--main-pack", "game.pck"],
                     ["--upwards"], ["--project-manager"], ["-p"],
                     ["/opt/heroesIsland/project.godot"], ["../project.godot"],
                     ["--gdscript-docs", "/source"], ["--remote-fs", "localhost:6010"]]:
            with self.subTest(args=args), self.assertRaises(qa_run.QAError):
                qa_run.validate_godot_args(args)

    def test_pass_marker_cannot_hide_failure(self):
        cases = [("CHECK PASSED\n", 1, False), ("SCRIPT ERROR\nCHECK PASSED\n", 0, False),
                 ("Parse Error\nCHECK PASSED\n", 0, False), ("Parser Error\nCHECK PASSED\n", 0, False),
                 ("CHECK PASSED\nCHECK FAILED\n", 0, False),
                 ("never finished\n", 0, False), ("CHECK PASSED\n", 0, True)]
        for output, code, timeout in cases:
            with self.subTest(output=output, code=code, timeout=timeout), self.assertRaises(qa_run.QAError):
                qa_run.check_result(self.result(output, code, timeout), "CHECK PASSED")
        qa_run.check_result(self.result("CHECK PASSED\n"), "CHECK PASSED")

    def test_fake_process_pass_cannot_hide_runtime_errors_and_keeps_full_log(self):
        diagnostics = [
            "ERROR: missing texture",
            "  ERROR: 6 resources still in use at exit",
            "ERROR: 472 RID allocations were leaked at exit",
        ]
        for index, diagnostic in enumerate(diagnostics):
            with self.subTest(diagnostic=diagnostic):
                output = "CHECK PASSED\n" + diagnostic + "\nremaining shutdown details\n"
                script = "import sys; print('CHECK PASSED'); " \
                    f"sys.stderr.write({(diagnostic + chr(10))!r}); " \
                    "print('remaining shutdown details')"
                result = qa_run.run_process(
                    [sys.executable, "-u", "-c", script],
                    self.root / f"runtime-error-{index}.log", 5,
                )
                self.assertEqual(result.returncode, 0)
                self.assertFalse(result.timed_out)
                self.assertEqual(result.log_path.read_text(), output)
                for expect in ("CHECK PASSED", None):
                    with self.subTest(expect=expect), self.assertRaisesRegex(
                            qa_run.QAError, "Godot error found; see") as failed:
                        qa_run.check_result(result, expect)
                    self.assertEqual(failed.exception.exit_code, 1)
                self.assertEqual(result.log_path.read_text(), output)

    def test_fake_process_normal_log_and_warning_keep_success_contract(self):
        output = "normal progress\nERROR_COUNT=0\nWARNING: optional diagnostic\nCHECK PASSED\n"
        result = qa_run.run_process(
            [sys.executable, "-u", "-c", f"print({output!r}, end='')"],
            self.root / "normal.log", 5,
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.log_path.read_text(), output)
        qa_run.check_result(result, "CHECK PASSED")
        qa_run.check_result(result)
        with self.assertRaisesRegex(qa_run.QAError, "Missing expected marker"):
            qa_run.check_result(result, "OTHER CHECK PASSED")

    def test_import_errors_are_rejected_even_with_exit_zero(self):
        session = qa_run.QASession(self.root, Path(sys.executable))
        with mock.patch.object(session, "run_godot", return_value=self.result("ERROR: missing texture\n")):
            with self.assertRaises(qa_run.QAError):
                session.import_project()

    def test_exclusive_lock_rejects_second_runner(self):
        lock = self.root / "qa.lock"
        with qa_run.ExclusiveGodotLock(lock):
            with self.assertRaises(qa_run.QAError):
                with qa_run.ExclusiveGodotLock(lock):
                    self.fail("second runner entered")
        with qa_run.ExclusiveGodotLock(lock):
            pass
        self.assertTrue(lock.exists())

    def test_process_inventory_covers_translocation_and_linux_names(self):
        output = """101 /private/var/AppTranslocation/id/d/Godot.app/Contents/MacOS/Godot
102 /opt/Godot_v4.7.1-stable_linux.x86_64
103 /usr/bin/godot4
104 /usr/bin/python3
"""
        with mock.patch.object(qa_run.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, output, "")):
            found = qa_run.godot_processes()
        self.assertEqual(len(found), 3)

    def test_wall_timeout_overrides_printed_pass(self):
        result = qa_run.run_process([sys.executable, "-u", "-c",
            "import time; print('CHECK PASSED'); time.sleep(30)"], self.root / "timeout.log", 0.2)
        self.assertEqual(result.returncode, 124)
        self.assertTrue(result.timed_out)
        self.assertLess(result.elapsed, 4)
        with self.assertRaises(qa_run.QAError):
            qa_run.check_result(result, "CHECK PASSED")

    def test_timeout_also_stops_a_child_that_ignores_term(self):
        pid_file = self.root / "child.pid"
        child = "import os,signal,time; from pathlib import Path; " \
            "signal.signal(signal.SIGTERM,signal.SIG_IGN); " \
            f"Path({str(pid_file)!r}).write_text(str(os.getpid())); time.sleep(30)"
        parent = "import subprocess,sys,time; " \
            f"subprocess.Popen({[sys.executable, '-c', child]!r}); time.sleep(30)"
        result = qa_run.run_process([sys.executable, "-c", parent], self.root / "child.log", 0.3)
        self.assertTrue(result.timed_out)
        self.assertEqual(result.returncode, 124)
        self.assertTrue(pid_file.exists())
        child_pid = pid_file.read_text()
        state = subprocess.run(["ps", "-p", child_pid, "-o", "stat="],
                               capture_output=True, text=True, check=False)
        # An already killed child may briefly wait for its new parent to reap it.
        self.assertTrue(state.returncode != 0 or state.stdout.strip().startswith("Z"), state.stdout)

    def test_suite_manifest_has_all_original_probes_in_order(self):
        suite = qa_run.load_suite(Path(__file__).with_name("smoke_suite.json"))
        self.assertEqual(len(suite), 29)
        self.assertEqual(suite[0]["name"], "SmokeTest")
        self.assertEqual(suite[-1]["name"], "SaveProbe")
        self.assertEqual(sum(entry["window"] for entry in suite), 8)
        self.assertEqual(next(entry["timeout"] for entry in suite if entry["name"] == "FarmWorldProbe"), 400)

    def test_suite_skips_gui_without_a_display(self):
        entries = [{"name": "headless", "args": ["--headless"], "expect": "OK", "timeout": 10, "window": False},
                   {"name": "window", "args": [], "expect": "OK", "timeout": 20, "window": True}]
        session = mock.Mock()
        with mock.patch.object(qa_run.sys, "platform", "linux"), mock.patch.dict(qa_run.os.environ, {}, clear=True), \
                mock.patch.object(qa_run.shutil, "which", return_value=None):
            qa_run.run_suite(session, entries)
        session.run_godot.assert_called_once()
        self.assertEqual(session.run_godot.call_args.kwargs["label"], "headless")

    def test_suite_xvfb_and_timeout_override(self):
        entries = [{"name": "window", "args": ["scene"], "expect": "OK", "timeout": 20, "window": True}]
        session = mock.Mock()
        with mock.patch.object(qa_run.sys, "platform", "linux"), mock.patch.dict(qa_run.os.environ, {}, clear=True), \
                mock.patch.object(qa_run.shutil, "which", return_value="/usr/bin/xvfb-run"):
            qa_run.run_suite(session, entries, timeout=8)
        options = session.run_godot.call_args.kwargs
        self.assertEqual(options["timeout"], 8)
        self.assertEqual(options["prefix"][0], "/usr/bin/xvfb-run")
        self.assertEqual(options["env"], {"LIBGL_ALWAYS_SOFTWARE": "1"})


if __name__ == "__main__":
    unittest.main()
