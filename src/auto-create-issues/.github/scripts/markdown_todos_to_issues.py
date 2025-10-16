import os, re, json, hashlib, urllib.request, urllib.parse
from pathlib import Path

REPO = os.environ["GITHUB_REPOSITORY"]
SHA = os.environ.get("GITHUB_SHA", "main")
TOKEN = os.environ["GITHUB_TOKEN"]

# Fichiers à ignorer (archive, templates, etc.)
IGNORE_DIRS = {".git", ".github", "node_modules", "vendor", ".venv", "venv"}
CACHE_PATH = Path(".github/todos-cache.json")

checkbox_re = re.compile(r"^\s*[-*]\s+\[(?P<checked>[ xX])\]\s+(?P<text>.+)$")
due_re = re.compile(r"\bdue:\s*(\d{4}-\d{2}-\d{2})\b", re.IGNORECASE)
label_re = re.compile(r"(?:^|\s)#([A-Za-z0-9._/-]+)")
prio_re = re.compile(r"(?:^|\s)!(p[123])\b", re.IGNORECASE)

def gh_api(method, path, data=None):
    url = f"https://api.github.com{path}"
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Accept", "application/vnd.github+json")
    if data is not None:
        body = json.dumps(data).encode("utf-8")
        req.add_header("Content-Type", "application/json")
    else:
        body = None
    with urllib.request.urlopen(req, body) as resp:
        return json.loads(resp.read().decode())

def list_md_files():
    for p in Path(".").rglob("*.md"):
        if any(part in IGNORE_DIRS for part in p.parts):
            continue
        yield p

def task_id(path, line_no, text):
    h = hashlib.sha1(f"{path}:{line_no}:{text}".encode("utf-8")).hexdigest()
    return h[:12]

def load_cache():
    if CACHE_PATH.exists():
        return json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    return {"open": {}, "closed": []}

def save_cache(cache):
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    CACHE_PATH.write_text(json.dumps(cache, indent=2), encoding="utf-8")

def ensure_labels(labels):
    existing = {}
    page = 1
    while True:
        res = gh_api("GET", f"/repos/{REPO}/labels?per_page=100&page={page}")
        if not res: break
        for l in res:
            existing[l["name"]] = True
        page += 1
    to_create = [l for l in labels if l not in existing]
    for name in to_create:
        gh_api("POST", f"/repos/{REPO}/labels", {"name": name})

def main():
    cache = load_cache()
    seen_ids = set()
    new_tasks = []

    for md in list_md_files():
        rel = md.as_posix()
        lines = md.read_text(encoding="utf-8", errors="ignore").splitlines()
        section = None
        for i, line in enumerate(lines, start=1):
            if line.startswith("#"):
                section = line.strip("# ").strip()
            m = checkbox_re.match(line)
            if not m: continue
            checked = m.group("checked").strip().lower() == "x"
            text = m.group("text").strip()
            tid = task_id(rel, i, text)
            seen_ids.add(tid)

            # Parse metadata
            due = None
            due_m = due_re.search(text)
            if due_m:
                due = due_m.group(1)
            labels = set(label_re.findall(text))
            prio = prio_re.search(text)
            if prio:
                labels.add(f"priority/{prio.group(1).lower()}")

            labels.add("from-markdown")

            # Build issue title (short) and body (rich)
            title = text
            # Nettoyage du title des marqueurs
            title = due_re.sub("", title)
            title = prio_re.sub("", title)
            title = re.sub(r"(?:^|\s)#[A-Za-z0-9._/-]+", "", title).strip()
            if len(title) > 120:
                title = title[:117] + "…"

            link = f"https://github.com/{REPO}/blob/{SHA}/{urllib.parse.quote(rel)}#L{i}"
            body = []
            body.append(f"Source: [{rel}:{i}]({link})")
            if section:
                body.append(f"Section: **{section}**")
            if due:
                body.append(f"**Due:** {due}")
            body.append("")
            body.append("```md")
            body.append(line.strip())
            body.append("```")
            body.append("")
            body.append(f"_Task ID: `{tid}`_")
            body = "\n".join(body)

            new_tasks.append({
                "id": tid,
                "checked": checked,
                "title": title,
                "body": body,
                "labels": sorted(labels),
            })

    # Crée labels si besoin
    all_labels = sorted({l for t in new_tasks for l in t["labels"]})
    ensure_labels(all_labels)

    # Sync: créer/mettre à jour/fermer
    # 1) Créer/MAJ
    for t in new_tasks:
        issue_no = cache["open"].get(t["id"])
        if issue_no:
            # Update state/title/body/labels si besoin
            try:
                gh_api("PATCH", f"/repos/{REPO}/issues/{issue_no}", {
                    "title": t["title"],
                    "body": t["body"],
                    "labels": t["labels"],
                    "state": "closed" if t["checked"] else "open",
                })
            except Exception:
                # Si l’issue n’existe plus, on recrée
                issue_no = None

        if not issue_no:
            if t["checked"]:
                # Ne pas créer d’issue pour une tâche déjà cochée
                continue
            res = gh_api("POST", f"/repos/{REPO}/issues", {
                "title": t["title"],
                "body": t["body"],
                "labels": t["labels"],
            })
            issue_no = res["number"]
        cache["open"][t["id"]] = issue_no

    # 2) Fermer les issues dont la ligne a disparu du repo
    vanished = [tid for tid in list(cache["open"].keys()) if tid not in seen_ids]
    for tid in vanished:
        issue_no = cache["open"].get(tid)
        if issue_no:
            try:
                gh_api("PATCH", f"/repos/{REPO}/issues/{issue_no}", {"state": "closed"})
            except Exception:
                pass
        cache["closed"].append(tid)
        del cache["open"][tid]

    save_cache(cache)

if __name__ == "__main__":
    main()
