#!/usr/bin/env python3
"""Bump fluxer-aio to a newer Fluxer compose-bundle release.

Used by .github/workflows/fluxer-release-watch.yml (weekly + manual) and
runnable by hand. It never builds or pushes anything; the workflow builds the
result as a test and opens a pull request for the maintainer to merge.

Steps:
  1. Find the latest bundle via https://docs.fluxer.com/compose/latest (the
     redirect Fluxer's own docs use; the GitHub repo also publishes desktop and
     per-service releases, so "latest release" there is not the bundle).
  2. Stop if upstream/RELEASE already names it.
  3. Download the bundle, record its SHA-256, extract it.
  4. Copy the image references the bundle pins into the Dockerfile's *_IMAGE
     arguments. If the bundle moves Meilisearch to another minor version,
     pick that minor's newest glibc release binary (+ its SHA-256 digest).
  5. Regenerate upstream/env/*.env with gen-env.py.
  6. Update upstream/RELEASE and audit.md (Upstream row, Last audited, a
     change-log row) and write a Markdown summary for the pull request.

Usage:
  python bump-release.py [--release fluxer-release@YYYY.MMDD.N] [--summary FILE] [--force]
Stdlib only. Writes `changed=true|false` and `release=...` to $GITHUB_OUTPUT
when it is set.
"""
import argparse
import datetime
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
IMAGE_DIR = os.path.dirname(HERE)
RELEASE_FILE = os.path.join(HERE, "RELEASE")
DOCKERFILE = os.path.join(IMAGE_DIR, "Dockerfile")
AUDIT = os.path.join(IMAGE_DIR, "audit.md")
ENV_DIR = os.path.join(HERE, "env")

LATEST_URL = "https://docs.fluxer.com/compose/latest"
BUNDLE_URL = ("https://github.com/fluxerapp/fluxer/releases/download/"
              "{tag_q}/fluxer-compose-{ver}.tar.gz")
UA = {"User-Agent": "fluxer-aio-release-watch"}

# Dockerfile ARG -> (bundle file, compose service). Values may be plain image
# references or Compose defaults like ${FLUXER_NATS_IMAGE:-nats:2.14-alpine@sha256:...}.
IMAGE_ARGS = {
    "FLUXER_API_IMAGE": ("docker-compose.yml", "api"),
    "FLUXER_GATEWAY_IMAGE": ("docker-compose.yml", "gateway"),
    "FLUXER_MEDIA_PROXY_IMAGE": ("docker-compose.yml", "media-proxy"),
    "FLUXER_SERVER_IMAGE": ("rust-server.compose.yml", "rust"),
    "FLUXER_STATIC_IMAGE": ("docker-compose.yml", "static-proxy"),
    "NATS_IMAGE": ("docker-compose.yml", "nats"),
    "LIVEKIT_IMAGE": ("docker-compose.yml", "livekit"),
    "CADDY_IMAGE": ("docker-compose.yml", "edge"),
}


def die(msg):
    sys.exit(f"bump-release: {msg}")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


def latest_tag():
    opener = urllib.request.build_opener(NoRedirect)
    try:
        opener.open(urllib.request.Request(LATEST_URL, headers=UA), timeout=30)
    except urllib.error.HTTPError as e:
        loc = e.headers.get("Location", "")
        if e.code in (301, 302, 303, 307, 308) and loc:
            m = re.search(r"/download/([^/]+)/fluxer-compose-", loc)
            if m:
                return urllib.parse.unquote(m.group(1))
            die(f"unexpected redirect target: {loc}")
        die(f"{LATEST_URL}: HTTP {e.code}")
    die(f"{LATEST_URL} did not redirect to a release")


def current_tag():
    return open(RELEASE_FILE, encoding="utf-8").readline().strip()


def version_of(tag):
    m = re.fullmatch(r"fluxer-release@(\d{4}\.\d{4}\.\d+)", tag)
    if not m:
        die(f"not a compose-bundle release tag: {tag!r}")
    return m.group(1)


def download(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
        return r.read()


def compose_image(path, service):
    """Image of `service` in a bundle compose file (default value if templated)."""
    text = open(path, encoding="utf-8").read()
    m = re.search(rf"^  {re.escape(service)}:\n((?:    .*\n|\s*\n)*)", text, re.M)
    if not m:
        die(f"service {service} not found in {os.path.basename(path)}")
    im = re.search(r"^    image:\s*(\S+)\s*$", m.group(1), re.M)
    if not im:
        die(f"no image for service {service} in {os.path.basename(path)}")
    ref = im.group(1).strip("\"'")
    d = re.fullmatch(r"\$\{[A-Z0-9_]+:-(.+)\}", ref)
    if d:
        ref = d.group(1)
    if "${" in ref or "@sha256:" not in ref:
        die(f"{service}: image is not a digest-pinned reference: {ref}")
    return ref


def gh_json(url):
    headers = dict(UA, Accept="application/vnd.github+json")
    if os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = f"Bearer {os.environ['GITHUB_TOKEN']}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as r:
        return json.load(r)


def meili_for_minor(minor):
    """Newest Meilisearch release vMINOR.N with its glibc binary digest."""
    best = None
    for page in (1, 2, 3):
        rels = gh_json(f"https://api.github.com/repos/meilisearch/meilisearch/releases?per_page=100&page={page}")
        for r in rels:
            m = re.fullmatch(rf"v{re.escape(minor)}\.(\d+)", r["tag_name"])
            if not m or r.get("prerelease") or r.get("draft"):
                continue
            asset = next((a for a in r["assets"] if a["name"] == "meilisearch-linux-amd64"), None)
            if asset and asset.get("digest", "").startswith("sha256:"):
                cand = (int(m.group(1)), r["tag_name"][1:], asset["digest"][7:])
                best = max(best, cand) if best else cand
        if not rels:
            break
    if not best:
        die(f"no Meilisearch {minor}.x release with a linux-amd64 binary digest found")
    return best[1], best[2]


def set_arg(text, name, value):
    new, n = re.subn(rf"^ARG {name}=.*$", f"ARG {name}={value}", text, flags=re.M)
    if n != 1:
        die(f"Dockerfile: expected exactly one 'ARG {name}=' line, found {n}")
    return new


def get_arg(text, name):
    m = re.search(rf"^ARG {name}=(.*)$", text, re.M)
    return m.group(1) if m else None


def read_env(path):
    out = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            if line.startswith(("#", "!")) or "=" not in line:
                continue
            k, v = line.rstrip("\n").split("=", 1)
            out[k] = v
    return out


def short(ref):
    name, _, dig = ref.partition("@sha256:")
    return f"`{name.split('/')[-1]}@{dig[:12]}`"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--release", help="bundle tag to move to (default: latest)")
    ap.add_argument("--summary", help="write a Markdown summary here")
    ap.add_argument("--force", action="store_true", help="re-apply even if RELEASE already matches")
    a = ap.parse_args()

    old_tag = current_tag()
    new_tag = a.release or latest_tag()
    new_ver = version_of(new_tag)
    gh_out = os.environ.get("GITHUB_OUTPUT")

    def output(changed):
        if gh_out:
            with open(gh_out, "a", encoding="utf-8") as f:
                f.write(f"changed={'true' if changed else 'false'}\nrelease={new_tag}\n")

    if new_tag == old_tag and not a.force:
        print(f"up to date: {old_tag}")
        output(False)
        return

    url = BUNDLE_URL.format(tag_q=urllib.parse.quote(new_tag, safe=""), ver=new_ver)
    print(f"bumping {old_tag} -> {new_tag}\n  {url}")
    blob = download(url)
    sha = hashlib.sha256(blob).hexdigest()

    tmp = tempfile.mkdtemp(prefix="fluxer-bundle-")
    try:
        with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as t:
            t.extractall(tmp, filter="data")
        # The bundle may or may not have a top-level folder.
        root = tmp
        if not os.path.exists(os.path.join(root, "docker-compose.yml")):
            subs = [d for d in os.listdir(tmp) if os.path.isdir(os.path.join(tmp, d))]
            if len(subs) == 1 and os.path.exists(os.path.join(tmp, subs[0], "docker-compose.yml")):
                root = os.path.join(tmp, subs[0])
            else:
                die("docker-compose.yml not found in the bundle")

        dockerfile = open(DOCKERFILE, encoding="utf-8").read()
        changes = []
        for arg, (fname, svc) in IMAGE_ARGS.items():
            new_ref = compose_image(os.path.join(root, fname), svc)
            old_ref = get_arg(dockerfile, arg)
            if old_ref != new_ref:
                changes.append((arg, old_ref, new_ref))
                dockerfile = set_arg(dockerfile, arg, new_ref)

        # Meilisearch: our glibc binary must stay on the bundle's minor version
        # (Meilisearch upgrades its database format between minors).
        meili_ref = compose_image(os.path.join(root, "docker-compose.yml"), "meilisearch")
        mm = re.search(r":v(\d+\.\d+)", meili_ref)
        if not mm:
            die(f"cannot read the Meilisearch version from {meili_ref}")
        cur_meili = get_arg(dockerfile, "MEILISEARCH_VERSION")
        meili_note = f"unchanged ({cur_meili})"
        if not (cur_meili or "").startswith(mm.group(1) + "."):
            ver, digest = meili_for_minor(mm.group(1))
            dockerfile = set_arg(dockerfile, "MEILISEARCH_VERSION", ver)
            dockerfile = set_arg(dockerfile, "MEILISEARCH_SHA256", digest)
            meili_note = f"**{cur_meili} -> {ver}** (bundle moved to v{mm.group(1)}; database upgrade on first start)"

        dockerfile = re.sub(r"^# --- Upstream images \(Fluxer release [^)]*\)",
                            f"# --- Upstream images (Fluxer release {new_ver})", dockerfile, flags=re.M)
        open(DOCKERFILE, "w", encoding="utf-8", newline="\n").write(dockerfile)

        # RELEASE first, because gen-env.py stamps the generated files with it.
        rel = open(RELEASE_FILE, encoding="utf-8").read()
        rel = rel.replace(old_tag, new_tag, 1)
        rel = re.sub(r"^# url: .*$", f"# url:    {url}", rel, flags=re.M)
        rel = re.sub(r"^# sha256: .*$", f"# sha256: {sha}", rel, flags=re.M)
        open(RELEASE_FILE, "w", encoding="utf-8", newline="\n").write(rel)

        before = {f[:-4]: read_env(os.path.join(ENV_DIR, f)) for f in os.listdir(ENV_DIR) if f.endswith(".env")}
        shutil.rmtree(ENV_DIR)
        subprocess.run([sys.executable, "-I", os.path.join(HERE, "gen-env.py"), root, ENV_DIR], check=True)
        after = {f[:-4]: read_env(os.path.join(ENV_DIR, f)) for f in os.listdir(ENV_DIR) if f.endswith(".env")}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    today = datetime.date.today().isoformat()
    old_ver = old_tag.partition("@")[2]
    audit = open(AUDIT, encoding="utf-8").read()
    audit = re.sub(r"(\| Upstream \| Fluxer `)fluxer-release@[^`]+(`)", rf"\g<1>{new_tag}\g<2>", audit)
    audit = re.sub(r"^\| Last audited \| .* \|$", f"| Last audited | {today} |", audit, flags=re.M)
    row = (f"| {today} | _(this change)_ | Fluxer release {old_ver} -> {new_ver} | "
           f"Automated bump (upstream/bump-release.py): image digests, env regenerated; "
           f"Meilisearch {meili_note.replace('**', '')}. Review the snapshot's version notes. |\n")
    audit, n = re.subn(r"(^\|---\|---\|---\|---\|\n)", r"\1" + row.replace("\\", "\\\\"), audit, count=1, flags=re.M)
    if n != 1:
        die("audit.md: change-log table not found")
    open(AUDIT, "w", encoding="utf-8", newline="\n").write(audit)

    lines = [f"## Fluxer release {old_ver} -> {new_ver}", "",
             f"Bundle: {url}  ", f"SHA-256: `{sha}`", "",
             "### Images", "", "| Arg | Old | New |", "|---|---|---|"]
    lines += [f"| `{a_}` | {short(o)} | {short(n_)} |" for a_, o, n_ in changes] or ["| (none) | | |"]
    lines += ["", f"Meilisearch: {meili_note}", "", "### Generated environment", ""]
    for svc in sorted(set(before) | set(after)):
        b, f_ = before.get(svc, {}), after.get(svc, {})
        added = sorted(set(f_) - set(b))
        removed = sorted(set(b) - set(f_))
        changed = sorted(k for k in set(b) & set(f_) if b[k] != f_[k])
        lines.append(f"- **{svc}**: {len(f_)} vars; +{len(added)} -{len(removed)} ~{len(changed)}")
        for label, keys in (("added", added), ("removed", removed), ("changed", changed)):
            if keys:
                lines.append(f"  - {label}: " + ", ".join(f"`{k}`" for k in keys[:25])
                             + (" …" if len(keys) > 25 else ""))
    lines += ["", "### Before merging", "",
              "- Read the env changes above: new required settings, renamed ports or",
              "  internal addresses (gen-env.py stops on addresses it can't map).",
              "- Check `audit.md` snapshot notes (Node/ERTS/library versions) if images changed.",
              "- Merging pushes to `main` and rebuilds fluxer-aio; then force update on Unraid.",
              "  The container backs up and validates the database before the new release",
              "  starts (README \"Backups\"); if that fails, Fluxer does not start."]
    summary = "\n".join(lines) + "\n"
    print(summary)
    if a.summary:
        open(a.summary, "w", encoding="utf-8").write(summary)
    output(True)


if __name__ == "__main__":
    main()
