import os
import sys

from lupa import lua52

here = os.path.dirname(os.path.abspath(__file__)).replace("\\", "/")
repo = os.path.dirname(here)

if len(sys.argv) < 2:
    print("usage: python tests/run.py <test.lua> [args...]")
    sys.exit(2)

lua = lua52.LuaRuntime(unpack_returned_tuples=True)
args = sys.argv[2:]
path = os.path.abspath(sys.argv[1]).replace("\\", "/")
lua.execute(
    'package.path = "%s/?.lua;%s/?.lua;" .. package.path\nREPO = "%s"\nHERE = "%s"\nARGS = {%s}'
    % (here, repo, repo, here, ",".join('"%s"' % a.replace("\\", "/") for a in args))
)
files = {}
for root, _, names in os.walk(os.path.join(repo, "vrb")):
    for n in names:
        full = os.path.join(root, n)
        rel = os.path.relpath(full, repo).replace("\\", "/")
        with open(full, "rb") as fh:
            files[rel] = fh.read().decode("latin-1")
lua.globals().REPO_FILES = lua.table_from(files)
lua.execute(
    """
local f, err = loadfile("%s")
if not f then io.stderr:write(tostring(err), "\\n") os.exit(1) end
local ok, e = xpcall(f, debug.traceback)
if not ok then io.stderr:write(tostring(e), "\\n") io.stdout:flush() os.exit(1) end
io.stdout:flush()
"""
    % path
)
