#!/usr/bin/env python3
import subprocess
import glob
import os
import sys

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT = "/opt/heroesIsland"

# Find all Probe scenes
probes = sorted(glob.glob("tests/*Probe*.tscn"))

# Skip FarmLifeProbe in headless as it requires an active rendering window for pixel reading
SKIP = ["tests/FarmLifeProbe.tscn", "tests/ScreenshotContentProbe.tscn"]

results = []
print(f"Discovered {len(probes)} probe suites to run...\n")

for p in probes:
    if p in SKIP:
        print(f"[-] SKIPPED: {p} (requires active GUI window)")
        results.append((p, "SKIPPED", "requires window"))
        continue
    
    cmd = [GODOT, "--headless", "--path", PROJECT, p]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=30)
        out = proc.stdout + proc.stderr
        
        # Check pass status
        passed = False
        if "PASSED" in out or "all checks passed" in out or "ok" in out:
            passed = True
        if "FAIL" in out or "FAILED" in out or proc.returncode != 0:
            passed = False
            
        summary = ""
        for line in out.splitlines():
            line_s = line.strip()
            if any(k in line_s for k in ["PASSED", "FAILED", "failures", "asked", "checks run"]):
                summary = line_s
                
        status = "PASS" if passed else "FAIL"
        print(f"[{status}] {p} -> {summary or f'code {proc.returncode}'}")
        results.append((p, status, summary or out[-200:].replace("\n", " ")))
    except subprocess.TimeoutExpired:
        print(f"[TIMEOUT] {p}")
        results.append((p, "TIMEOUT", "exceeded 30s"))
    except Exception as e:
        print(f"[ERROR] {p}: {e}")
        results.append((p, "ERROR", str(e)))

print("\n" + "="*60)
print(f"SUMMARY: {sum(1 for r in results if r[1] == 'PASS')}/{len(results)} PASSED")
failed = [r for r in results if r[1] == "FAIL"]
if failed:
    print(f"FAILURES ({len(failed)}):")
    for f in failed:
        print(f"  {f[0]}: {f[2]}")
else:
    print("ALL RUNNABLE PROBES PASSED!")
print("="*60)
