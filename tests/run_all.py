import glob
import os
import re
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
runner = os.path.join(here, "run.py")
only = sys.argv[1:]
files = sorted(glob.glob(os.path.join(here, "test_*.lua")))
if only:
    files = [f for f in files if any(o in os.path.basename(f) for o in only)]

total_pass = total_fail = 0
bad = []
for path in files:
    name = os.path.basename(path)
    proc = subprocess.run([sys.executable, "-I", runner, path], capture_output=True, text=True, timeout=1800)
    out = proc.stdout + proc.stderr
    m = re.search(r"(\d+) passed, (\d+) failed", out)
    if m and proc.returncode == 0:
        p, f = int(m.group(1)), int(m.group(2))
        total_pass += p
        total_fail += f
        print("%-24s %4d passed, %d failed" % (name, p, f))
    else:
        total_fail += 1
        bad.append(name)
        print("%-24s FAILED" % name)
        print("\n".join("    " + l for l in out.strip().splitlines()[-12:]))
print("")
print("%d passed, %d failed in %d files" % (total_pass, total_fail, len(files)))
sys.exit(1 if total_fail or bad else 0)
