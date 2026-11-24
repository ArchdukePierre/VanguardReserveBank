import hashlib
import json
import os
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROLE_NAMES = ["atm", "admin", "viewer", "shop", "mint", "pos", "scoreboard"]


def rel(path):
    return os.path.relpath(path, root).replace("\\", "/")


def roles_for(path):
    if path.startswith("vrb/server/"):
        return ["server"], False
    if path.startswith("vrb/ui/"):
        return list(ROLE_NAMES), False
    if path.startswith("vrb/roles/"):
        name = path[len("vrb/roles/"):].split("/")[0].replace(".lua", "")
        return [name], False
    if path in ("vrb/lib/pairing.lua",):
        return [], True
    return [], True


def lua_value(v, indent=0):
    pad = "  " * indent
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        if all(isinstance(x, str) for x in v):
            return "{ " + ", ".join(json.dumps(x) for x in v) + " }"
        return "{\n" + "".join(pad + "  " + lua_value(x, indent + 1) + ",\n" for x in v) + pad + "}"
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            parts.append("%s = %s" % (k, lua_value(x, indent + 1)))
        return "{ " + ", ".join(parts) + " }"
    raise TypeError(type(v))


def main():
    version = None
    with open(os.path.join(root, "vrb", "lib", "defaults.lua"), encoding="utf-8") as fh:
        for line in fh:
            if "D.VERSION" in line:
                version = line.split('"')[1]
    files = []
    for base, _, names in os.walk(os.path.join(root, "vrb")):
        for n in sorted(names):
            if not n.endswith(".lua"):
                continue
            full = os.path.join(base, n)
            data = open(full, "rb").read()
            data = data.replace(bytes([13, 10]), bytes([10]))
            r, all_roles = roles_for(rel(full))
            entry = {"path": rel(full), "size": len(data), "sha": hashlib.sha256(data).hexdigest()}
            if all_roles:
                entry["all"] = True
            else:
                entry["roles"] = r
            files.append(entry)
    data = open(os.path.join(root, "install.lua"), "rb").read()
    data = data.replace(bytes([13, 10]), bytes([10]))
    files.append({"path": "install.lua", "dest": "vrb/install.lua", "size": len(data), "sha": hashlib.sha256(data).hexdigest(), "all": True})
    files.sort(key=lambda e: e["path"])
    out = ["return {", '  version = "%s",' % version, "  files = {"]
    for e in files:
        out.append("    " + lua_value(e) + ",")
    out.append("  },")
    out.append("}")
    with open(os.path.join(root, "manifest.lua"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
    print("manifest.lua: %d files, version %s" % (len(files), version))


if __name__ == "__main__":
    main()
