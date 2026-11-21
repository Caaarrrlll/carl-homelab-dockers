#!/usr/bin/env python3
"""Decide which images CI builds, from .github/images.json (stdlib only).

Rules (ROADMAP item 16):
  push        images whose folder has a changed non-.md file, plus every image
              built on them (transitively). A change to the CI files themselves
              (workflow, this script, images.json, the build action) = all
              non-opt-in images. A brand-new branch (no "before") = all.
  tag (v*)    all non-opt-in images.
  schedule    all non-opt-in images (monthly rebuild).
  manual      the images named in IMAGES ("all" = all non-opt-in), plus every
              image built on them. Opt-in images only when named.
Images are grouped into dependency levels (parents first); each level is
built in parallel after the previous one.

Environment:
  EVENT           github.event_name (push | schedule | workflow_dispatch)
  REF             github.ref (refs/tags/v... for tags)
  BEFORE, AFTER   push range (git diff --name-only BEFORE AFTER)
  IMAGES          manual input: "all" or comma/space separated names
  CHANGED_FILES   optional newline-separated list (tests); skips git
  GITHUB_OUTPUT, GITHUB_STEP_SUMMARY   set by GitHub Actions
Outputs: level0 .. level{MAX_LEVEL} (JSON arrays for a matrix), any (true/false).
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
IMAGES_FILE = os.path.join(ROOT, ".github", "images.json")
RETAG_FILE = os.path.join(ROOT, ".github", "workflows", "retag-image.yml")
MAX_LEVEL = 2          # the workflow has build jobs for levels 0..2
CI_FILES = (
    ".github/workflows/build-images.yml",
    ".github/images.json",
    ".github/scripts/plan-builds.py",
    ".github/actions/build-image/",
)
ZERO_SHA = re.compile(r"^0+$")


def die(msg):
    print(f"plan-builds: ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def load_images():
    with open(IMAGES_FILE, encoding="utf-8") as f:
        images = json.load(f)["images"]
    for name, img in images.items():
        for key in ("context", "image"):
            if not img.get(key):
                die(f"{name}: missing '{key}' in images.json")
        if img.get("parent") and img["parent"] not in images:
            die(f"{name}: parent '{img['parent']}' is not in images.json")
    return images


def level_of(images, name, seen=()):
    parent = images[name].get("parent")
    if not parent:
        return 0
    if parent in seen:
        die(f"parent cycle at {name}")
    return 1 + level_of(images, parent, seen + (name,))


def with_dependents(images, names):
    """Names plus every image built on them, transitively."""
    out = set(names)
    grew = True
    while grew:
        grew = False
        for name, img in images.items():
            if name not in out and img.get("parent") in out:
                out.add(name)
                grew = True
    return out


def changed_files():
    if os.environ.get("CHANGED_FILES") is not None:
        return [f for f in os.environ["CHANGED_FILES"].splitlines() if f.strip()]
    before = os.environ.get("BEFORE", "")
    after = os.environ.get("AFTER", "HEAD")
    if not before or ZERO_SHA.match(before):
        return None  # new branch / unknown range: build everything
    result = subprocess.run(
        ["git", "diff", "--name-only", before, after],
        cwd=ROOT, capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"plan-builds: git diff failed ({result.stderr.strip()}); building everything",
              file=sys.stderr)
        return None
    return [f for f in result.stdout.splitlines() if f.strip()]


def resolve_names(images, text):
    """Manual input: entry names or Docker Hub image names, or 'all'."""
    by_image = {img["image"]: name for name, img in images.items()}
    wanted, unknown = set(), []
    for token in re.split(r"[,\s]+", text.strip()):
        if not token:
            continue
        if token == "all":
            wanted |= {n for n, i in images.items() if not i.get("opt_in")}
        elif token in images:
            wanted.add(token)
        elif token in by_image:
            wanted.add(by_image[token])
        else:
            unknown.append(token)
    if unknown:
        die(f"unknown image(s) {unknown}; known: {sorted(images)}")
    return wanted


def plan(images, event, ref):
    """Returns (set of names to build, {name: reason})."""
    default = {n for n, i in images.items() if not i.get("opt_in")}
    if event == "schedule":
        return default, {n: "monthly schedule" for n in default}
    if ref.startswith("refs/tags/"):
        return default, {n: "tag push" for n in default}
    if event == "workflow_dispatch":
        named = resolve_names(images, os.environ.get("IMAGES", "all") or "all")
        build = with_dependents(images, named)
        return build, {n: ("named" if n in named else "built on a named image") for n in build}
    if event != "push":
        die(f"unexpected event '{event}'")

    files = changed_files()
    if files is None:
        return default, {n: "new branch or unknown range" for n in default}
    if any(f == c or f.startswith(c) for f in files for c in CI_FILES):
        return default, {n: "CI files changed" for n in default}
    direct = set()
    for name, img in images.items():
        prefix = img["context"].rstrip("/") + "/"
        if any(f.startswith(prefix) and not f.endswith(".md") for f in files):
            direct.add(name)
    build = with_dependents(images, direct)
    reasons = {n: ("files changed" if n in direct else "built on a changed image") for n in build}
    return build, reasons


def check_retag_list(images):
    """The Retag workflow's choice list must name every image."""
    try:
        text = open(RETAG_FILE, encoding="utf-8").read()
    except OSError:
        return []
    return [img["image"] for img in images.values()
            if not re.search(rf"^\s*-\s*{re.escape(img['image'])}\s*$", text, re.M)]


def main():
    images = load_images()
    event = os.environ.get("EVENT", "")
    ref = os.environ.get("REF", "")
    build, reasons = plan(images, event, ref)

    levels = {lvl: [] for lvl in range(MAX_LEVEL + 1)}
    for name in sorted(build):
        lvl = level_of(images, name)
        if lvl > MAX_LEVEL:
            die(f"{name} is at dependency level {lvl}; add a build-level-{lvl} job")
        img = images[name]
        levels[lvl].append({
            "name": name,
            "context": img["context"],
            "image": img["image"],
            "tag_prefix": img.get("tag_prefix", ""),
        })

    lines = [f"## Build plan ({event}{', ' + ref if ref.startswith('refs/tags/') else ''})", "",
             "| Image | Level | Build | Why |", "|---|---|---|---|"]
    for name in sorted(images, key=lambda n: (level_of(images, n), n)):
        built = name in build
        lines.append(f"| `{name}` | {level_of(images, name)} | {'yes' if built else 'no'} | "
                     f"{reasons.get(name, 'opt-in' if images[name].get('opt_in') else 'unchanged')} |")
    missing = check_retag_list(images)
    if missing:
        lines += ["", f"WARNING: the Retag image workflow does not list {missing}; add them."]
    summary = "\n".join(lines) + "\n"
    print(summary)

    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as f:
            for lvl, items in levels.items():
                f.write(f"level{lvl}={json.dumps(items)}\n")
            f.write(f"any={'true' if build else 'false'}\n")
    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a", encoding="utf-8") as f:
            f.write(summary)
    if missing:
        print(f"::warning::Retag image workflow does not list {missing}")


if __name__ == "__main__":
    main()
