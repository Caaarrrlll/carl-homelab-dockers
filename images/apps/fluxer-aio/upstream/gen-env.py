#!/usr/bin/env python3
"""Generate fluxer-aio's per-service environment files from Fluxer's
official Docker Compose bundle.

Why: the bundle gives every Fluxer service a long list of environment
variables written as Compose interpolations (`${VAR:-default}`). fluxer-aio
runs all services in one container, so it needs the same variables. Copying
them by hand would drift with every Fluxer release; this script converts the
pinned bundle instead, so a release bump is "download, re-run, review diff".

Compose interpolation uses the same `${VAR}`, `${VAR:-x}`, `${VAR:+x}` forms
as POSIX shell. Each output line is `KEY=EXPR` with EXPR copied verbatim
(minus YAML quoting). The container's `fluxer-env` helper evaluates every
EXPR against the container environment (template values + generated
secrets), exactly like Compose evaluates them against `.env`.

Internal service addresses (`http://api:8080`, `nats://nats:4222`, ...) are
rewritten to fluxer-aio's 127.0.0.1 ports (see PORTS below and the README).
The bundled Postgres/Valkey/SeaweedFS defaults are blanked: fluxer-aio uses
the maintainer's own Postgres and Redis and stores uploads on disk.

Usage (stdlib only, no PyYAML):
  python gen-env.py <extracted-bundle-dir> <output-env-dir>

It parses only the subset of YAML the bundle uses for environments (block
maps, `<<: *anchor` merges, quoted/plain scalars) and fails loudly on
anything it does not understand, rather than guessing.
"""
import os
import re
import sys

# fluxer-aio internal ports (keep in sync with the README "Ports" table,
# rootfs/etc/fluxer-aio/overlay/*.env and the Caddyfile).
REWRITES = [
    ("http://edge:8088/.well-known/fluxer", "http://127.0.0.1:18080/.well-known/fluxer"),
    ("http://api:8080", "http://127.0.0.1:18080"),
    ("http://media-proxy:8080", "http://127.0.0.1:18085"),
    ("nats://nats:4222", "nats://127.0.0.1:4222"),
    ("http://meilisearch:7700", "http://127.0.0.1:7700"),
    ("http://livekit:7880", "http://127.0.0.1:7880"),
    # Bundled services fluxer-aio does not run: blank the defaults so the
    # user's settings (or the filesystem store) are used instead.
    ("http://seaweedfs:8333", ""),
    ("redis://valkey:6379/0", ""),
    ("${FLUXER_POSTGRES_HOST:-postgres}", "${FLUXER_POSTGRES_HOST:-}"),
]

# Services fluxer-aio runs, and where their environment comes from.
MAIN_SERVICES = ["api", "worker", "gateway", "media-proxy"]
RUST_SERVICE = "rust"  # from rust-server.compose.yml (all Rust services in one process)
FS_OVERRIDE_SERVICES = ["api", "worker", "media-proxy"]

# Values that would be unsafe or ambiguous to eval in the container.
FORBIDDEN = ['"', "`", "\\", "$(", "$$"]
LEFTOVER_HOST = re.compile(r"://(api|worker|gateway|media-proxy|nats|meilisearch|livekit|seaweedfs|edge|valkey|postgres|admin|app-proxy)\b")

KEY_RE = re.compile(r"^(?P<indent> *)(?P<key>[A-Za-z_][A-Za-z0-9_.-]*|<<):(?:\s+(?P<val>.*))?$")


def die(msg):
    sys.exit(f"gen-env: {msg}")


DQ_ESCAPE = re.compile(r'\\(U[0-9A-Fa-f]{8}|u[0-9A-Fa-f]{4}|x[0-9A-Fa-f]{2}|.)')
DQ_SIMPLE = {'"': '"', "\\": "\\", "/": "/", "n": "\n", "t": "\t", "0": "\0"}


def unescape_dq(s, where):
    """YAML double-quoted scalar escapes (the subset the bundle uses)."""
    def sub(m):
        e = m.group(1)
        if e[0] in "Uux" and len(e) > 1:
            return chr(int(e[1:], 16))
        if e in DQ_SIMPLE:
            return DQ_SIMPLE[e]
        die(f"unsupported escape \\{e} at {where}")
    return DQ_ESCAPE.sub(sub, s)


def scalar(raw, where):
    raw = raw.strip()
    if raw in ("|", ">", "|-", ">-"):
        return None  # block scalar: caller skips it
    if len(raw) >= 2 and raw[0] == raw[-1] == '"':
        return unescape_dq(raw[1:-1], where)
    if len(raw) >= 2 and raw[0] == raw[-1] == "'":
        return raw[1:-1].replace("''", "'")
    if raw.startswith(("\"", "'")):
        die(f"unterminated quoted value at {where}")
    return raw


def parse(path):
    """Return (anchors, services): name -> {'merge': [...], 'env': {k: v}, 'blocks': [...]}."""
    anchors, services = {}, {}
    lines = open(path, encoding="utf-8").read().split("\n")
    i, n = 0, len(lines)
    current = None          # dict being filled
    env_indent = None       # indent of entries in the current env block
    in_services = False
    service = None
    skip_deeper_than = None

    def new_block():
        return {"merge": [], "env": {}, "blocks": []}

    while i < n:
        line = lines[i]
        lineno = i + 1
        i += 1
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))
        if skip_deeper_than is not None:
            if indent > skip_deeper_than:
                continue
            skip_deeper_than = None

        if indent == 0:
            current, env_indent, service = None, None, None
            in_services = stripped == "services:"
            m = re.match(r"^x-[a-z0-9-]+:\s+&([a-z0-9-]+)\s*$", stripped)
            if m and m.group(1).endswith("-env"):
                current = anchors.setdefault(m.group(1), new_block())
                env_indent = 2
            continue

        if in_services and indent == 2 and stripped.endswith(":"):
            service = stripped[:-1]
            current, env_indent = None, None
            continue
        if in_services and service and indent == 4:
            if stripped == "environment:":
                current = services.setdefault(service, new_block())
                env_indent = 6
            else:
                current, env_indent = None, None
            continue

        if current is not None and indent == env_indent:
            m = KEY_RE.match(line)
            if not m:
                die(f"{path}:{lineno}: unexpected environment line: {stripped!r}")
            key, val = m.group("key"), m.group("val") or ""
            if key == "<<":
                ref = val.strip()
                if not ref.startswith("*"):
                    die(f"{path}:{lineno}: unsupported merge {ref!r}")
                current["merge"].append(ref[1:])
                continue
            v = scalar(val, f"{path}:{lineno}")
            if v is None:
                current["blocks"].append(key)
                skip_deeper_than = indent
                continue
            current["env"][key] = v
            continue
        if current is not None and indent > env_indent:
            die(f"{path}:{lineno}: nested value inside an environment block (not supported): {stripped!r}")
    return anchors, services


def resolve(block, anchors, seen=()):
    """YAML merge semantics: merged keys first, explicit keys win."""
    out = {}
    for ref in block["merge"]:
        if ref in seen:
            die(f"anchor cycle via {ref}")
        if ref not in anchors:
            die(f"unknown anchor *{ref}")
        out.update(resolve(anchors[ref], anchors, seen + (ref,)))
    out.update(block["env"])
    return out


def matching_brace(s, start):
    """Index of the `}` closing the `${` at s[start]; Compose balances all braces."""
    depth = 0
    for j in range(start + 1, len(s)):
        if s[j] == "{":
            depth += 1
        elif s[j] == "}":
            depth -= 1
            if depth == 0:
                return j
    die(f"unbalanced braces in {s!r}")


def hoist(key, expr, literals):
    """Bash ends `${A:-word}` at the first `}` even inside word, Compose does not.
    Move literal defaults that contain braces into their own variables."""
    out, i = [], 0
    while True:
        j = expr.find("${", i)
        if j < 0:
            out.append(expr[i:])
            return "".join(out)
        out.append(expr[i:j])
        end = matching_brace(expr, j)
        inner = expr[j + 2:end]
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)(:?[-+?])?(.*)$", inner, re.S)
        if not m:
            die(f"{key}: cannot parse ${{{inner}}}")
        name, op, word = m.group(1), m.group(2) or "", m.group(3)
        if op and word:
            if "{" in word or "}" in word:
                if "$" in word:
                    word = hoist(key, word, literals)
                    if re.search(r"(?<!\$)[{}]", word.replace("${", "").replace("}", "", word.count("${"))):
                        die(f"{key}: default mixes braces and variables: {inner!r}")
                else:
                    lit = f"__AIO_LIT_{key}_{len(literals)}"
                    literals.append((lit, word))
                    word = "${" + lit + "}"
            else:
                word = hoist(key, word, literals)
        out.append("${" + name + op + word + "}")
        i = end + 1


def rewrite(key, expr, literals):
    for old, new in REWRITES:
        expr = expr.replace(old, new)
    for bad in FORBIDDEN:
        if bad == '"':
            continue  # escaped below; safe inside the double-quoted eval
        if bad in expr:
            die(f"{key}: value contains {bad!r}, refusing to emit it for eval: {expr!r}")
    if key.upper() not in ("NO_PROXY",) and LEFTOVER_HOST.search(expr):
        die(f"{key}: unmapped internal address in {expr!r}; add it to REWRITES")
    expr = hoist(key, expr, literals)
    return expr.replace('"', '\\"')


def write(outdir, name, env, release, blocks):
    path = os.path.join(outdir, f"{name}.env")
    literals, lines = [], []
    for key in sorted(env):
        lines.append(f"{key}={rewrite(key, env[key], literals)}\n")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"# GENERATED by upstream/gen-env.py from Fluxer compose bundle {release}.\n")
        f.write("# Do not edit by hand: re-run the generator after a release bump.\n")
        f.write("# Format: KEY=<Compose interpolation>, evaluated by fluxer-env at start\n")
        f.write("# inside a bash double-quoted string. `!NAME=value` lines are literal\n")
        f.write("# defaults (assigned first, never evaluated).\n")
        for b in blocks:
            f.write(f"# skipped block scalar: {b} (handled in the image)\n")
        for lit, value in literals:
            f.write(f"!{lit}={value}\n")
        f.writelines(lines)
    return path


def main():
    if len(sys.argv) != 3:
        die("usage: gen-env.py <extracted-bundle-dir> <output-env-dir>")
    bundle, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    release = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "RELEASE"),
                   encoding="utf-8").readline().strip()

    anchors, services = parse(os.path.join(bundle, "docker-compose.yml"))
    _, rust_services = parse(os.path.join(bundle, "rust-server.compose.yml"))
    _, fs_services = parse(os.path.join(bundle, "filesystem-object-store.compose.yml"))

    for name in MAIN_SERVICES:
        if name not in services:
            die(f"service {name} not found in docker-compose.yml")
        env = resolve(services[name], anchors)
        if name in FS_OVERRIDE_SERVICES:
            if name not in fs_services:
                die(f"service {name} not found in filesystem-object-store.compose.yml")
            env.update(resolve(fs_services[name], anchors))
        print(write(outdir, name, env, release, services[name]["blocks"]), len(env), "vars")

    if RUST_SERVICE not in rust_services:
        die("service rust not found in rust-server.compose.yml")
    env = resolve(rust_services[RUST_SERVICE], anchors)
    print(write(outdir, RUST_SERVICE, env, release, rust_services[RUST_SERVICE]["blocks"]), len(env), "vars")


if __name__ == "__main__":
    main()
