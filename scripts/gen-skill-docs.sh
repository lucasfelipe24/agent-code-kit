#!/usr/bin/env bash
#
# gen-skill-docs.sh — Generate the docs site's pages from the kit's own sources
#
# Writes Fumadocs pages into web/content/docs so the site never drifts from the
# kit: README sections (English and pt-BR), skills, agents, module payloads,
# agent_docs guides and the changelog. Also writes web/content/site-data.json
# (counts and skill groups) for the landing page. Kit-maintainer only; the
# installer never ships it (ADR-036).
#
# Usage:
#   ./scripts/gen-skill-docs.sh              # (re)generate into web/content/docs
#   ./scripts/gen-skill-docs.sh --check      # exit 1 if the tree on disk is stale
#   ./scripts/gen-skill-docs.sh --dry-run    # list what would be written
#   ./scripts/gen-skill-docs.sh --out <dir>  # generate somewhere else
#
# Pages are plain Markdown (.md), not MDX: kit docs are written for GitHub and
# carry `<`, `{}` and HTML that MDX rejects. Only the generated folders below
# are replaced; each carries a .generated marker, and a folder without one is
# never deleted. Hand-written pages (index.mdx, index.pt-BR.mdx, meta.json)
# live beside them.
#
# Source paths are looked up in order, so the script keeps working while the
# R2 layout moves (ADR-031) land: the .claude/kit/ path first, then today's.
#
# Exit codes: 0 generated / up to date · 1 --check found drift, or a source is
#             missing · 2 bad usage or python3 missing
#

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$KIT_ROOT/web/content/docs"
MODE="write"

while [[ $# -gt 0 ]]; do
  case $1 in
    --out)
      [ $# -ge 2 ] || { echo "gen-skill-docs: --out requires a directory argument" >&2; exit 2; }
      case "$2" in /*) OUT_DIR="$2" ;; *) OUT_DIR="$(pwd)/$2" ;; esac
      shift 2 ;;
    --check) MODE="check"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    --help|-h)
      sed -n '1,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "gen-skill-docs: unknown option: $1" >&2; exit 2 ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "gen-skill-docs: python3 is required" >&2
  exit 2
fi

KIT_ROOT="$KIT_ROOT" OUT_DIR="$OUT_DIR" MODE="$MODE" python3 - <<'PY'
import json, os, re, shutil, sys, tempfile

ROOT = os.environ["KIT_ROOT"]
OUT_DIR = os.environ["OUT_DIR"]
MODE = os.environ["MODE"]
REPO_URL = "https://github.com/lucasfelipe24/agent-code-kit"
BLOB = REPO_URL + "/blob/main/"
TREE = REPO_URL + "/tree/main/"
RAW = "https://raw.githubusercontent.com/lucasfelipe24/agent-code-kit/main/"
LANGS = ["en", "pt-BR"]
MARKER = ".generated"

# --- Source paths: layout-2 path first (ADR-031), then the current one -------
SOURCES = {
    "skills":        [".claude/skills"],
    "agents":        [".claude/agents/kit", ".claude/agents"],
    "guides":        [".claude/kit/docs", "agent_docs"],
    "hooks":         [".claude/kit/hooks", ".claude/hooks"],
    "wiki_payload":  ["wiki-module/.claude"],
    "wiki_schema":   [".claude/kit/modules/wiki/WIKI.md", "WIKI.md"],
    "html_schema":   [".claude/kit/modules/html/ARTIFACTS.md", "ARTIFACTS.md"],
    "examples":      ["examples"],
    "changelog":     ["CHANGELOG.md"],
    "version":       ["VERSION"],
    "readme":        ["README.md"],
    "readme_pt":     ["README.pt-BR.md"],
}

def src(key):
    for rel in SOURCES[key]:
        if os.path.exists(os.path.join(ROOT, rel)):
            return rel
    sys.exit(f"gen-skill-docs: no source for {key}: tried {', '.join(SOURCES[key])}")

# --- README sections → guide pages, keyed by the emoji both READMEs share ----
GUIDE_PAGES = [
    ("why",                 ["🤔", "✨"]),
    ("how-it-works",        ["🧩", "📏"]),
    ("quick-start",         ["🚀"]),
    ("session",             ["🔁"]),
    ("workflows",           ["🧭"]),
    ("guardrails",          ["🚧"]),
    ("what-gets-installed", ["📦"]),
    ("configuration",       ["🔧"]),
    ("upgrade",             ["🔄", "🧹"]),
    ("other-tools",         ["🔌", "🤖"]),
    ("faq",                 ["❓"]),
    ("testing",             ["🧪"]),
]
SKILLS_SECTION = "🧰"

FOLDER_TITLES = {
    "guide":        {"en": "Guide",        "pt-BR": "Guia"},
    "skills":       {"en": "Skills",       "pt-BR": "Skills"},
    "agents":       {"en": "Agents",       "pt-BR": "Agentes"},
    "modules":      {"en": "Modules",      "pt-BR": "Módulos"},
    "agent-guides": {"en": "Agent guides", "pt-BR": "Guias do agente"},
}
OVERVIEW = {"en": "Overview", "pt-BR": "Visão geral"}
OTHER_GROUP = {"en": "Other", "pt-BR": "Outras"}
CHANGELOG_TITLE = {"en": "Changelog", "pt-BR": "Changelog"}

# --- Small helpers -----------------------------------------------------------
def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()

def gh_slug(text):
    """GitHub / github-slugger heading id: what both GitHub and Fumadocs use."""
    text = re.sub(r"<[^>]+>", "", text).strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")

def strip_emoji(text):
    return re.sub(r"^[^\w`*\[(]+", "", text).strip()

def title_case(name):
    return " ".join(w[:1].upper() + w[1:] for w in name.replace("-", " ").split())

def split_frontmatter(text):
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---", 4)
    if end < 0:
        return {}, text
    block, body = text[4:end], text[end + 4:].lstrip("\n")
    meta, key = {}, None
    for line in block.splitlines():
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            meta[key] = "" if val in (">", "|", ">-", "|-") else val.strip("\"'")
        elif key and line.startswith((" ", "\t")):
            meta[key] = (meta[key] + " " + line.strip()).strip()
    return meta, body

def strip_h1(body):
    lines = body.lstrip("\n").splitlines()
    if lines and lines[0].startswith("# "):
        return lines[0][2:].strip(), "\n".join(lines[1:]).lstrip("\n")
    return None, body

def plain(text):
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"[`*_]", "", text).strip()

def first_paragraph(body):
    para, fence = [], False
    for line in body.splitlines():
        s = line.strip()
        if s.startswith(("```", "~~~")):
            fence = not fence
            continue
        if fence:
            continue
        if not s:
            if para:
                break
            continue
        if s.startswith(("#", "|", "-", "*", ">", "<", "!")) or re.match(r"^\d+\.", s):
            if para:
                break
            continue
        para.append(s)
    return plain(" ".join(para))

def shorten(desc, limit=200):
    """Whole sentences up to `limit` chars; a lead-in ending in ':' is dropped.
    A single sentence longer than the limit is cut at a word boundary."""
    sentences = [x for x in re.split(r"(?<=[.!?])\s+", desc.strip()) if x]
    out = ""
    for sentence in sentences:
        if sentence.endswith(":"):
            break
        if out and len(out) + 1 + len(sentence) > limit:
            break
        out = f"{out} {sentence}".strip()
    if len(out) > limit:
        out = out[:limit].rsplit(" ", 1)[0].rstrip(".,;:")
    return out.rstrip(".")

def front(title, description, source):
    lines = ["---", f"title: {json.dumps(title, ensure_ascii=False)}"]
    description = shorten(description) if description else ""
    if description:
        lines.append(f"description: {json.dumps(description, ensure_ascii=False)}")
    lines.append(f"source: {json.dumps(source)}")
    lines.append("---")
    return "\n".join(lines) + "\n\n"

# --- <details> blocks → headings ---------------------------------------------
# A summary becomes a heading one level below the heading it sits under (never
# above `base`), so a collapsed FAQ answer reads as a question in the TOC.
def details_to_headings(body, base):
    out, current, fence = [], base - 1, False
    for line in body.splitlines():
        s = line.strip()
        if s.startswith(("```", "~~~")):
            fence = not fence
        if not fence:
            h = re.match(r"^(#{2,6}) ", line)
            if h:
                current = len(h.group(1))
            if s in ("<details>", "</details>") or s.startswith("<details "):
                continue
            m = re.match(r"^<summary>(.*)</summary>$", s)
            if m:
                text = re.sub(r"</?b>", "", m.group(1))
                text = re.sub(r"<code>(.*?)</code>", r"`\1`", text)
                level = min(max(current + 1, base), 6)
                out += ["", "#" * level + " " + re.sub(r"<[^>]+>", "", text).strip(), ""]
                continue
        out.append(line)
    return "\n".join(out)

# --- README parsing ----------------------------------------------------------
def readme_sections(text):
    """[(emoji, heading_text, body)] for every `## ` section, code fences respected."""
    sections, cur, fence = [], None, False
    for line in text.splitlines():
        if line.strip().startswith(("```", "~~~")):
            fence = not fence
        if not fence and line.startswith("## "):
            head = line[3:].strip()
            emoji = head.split(" ", 1)[0] if not head[:1].isalnum() else ""
            cur = [emoji, head, []]
            sections.append(cur)
        elif cur is not None:
            cur[2].append(line)
    return [(e, h, "\n".join(b).strip("\n")) for e, h, b in sections]

def skill_groups(body):
    """[(group, [(skill, description)])] from the bold-labelled tables of the skills
    section, plus {skill: description} from every table row (the intro table too)."""
    groups, cur, described = [], None, {}
    for line in body.splitlines():
        m = re.match(r"^\*\*([^*]+)\*\*\s*$", line.strip())
        if m:
            cur = (m.group(1).strip(), [])
            groups.append(cur)
            continue
        m = re.match(r"^\|\s*`/([a-z0-9-]+)`\s*\|\s*(.*?)\s*\|\s*$", line)
        if m:
            described.setdefault(m.group(1), plain(m.group(2)))
            if cur is not None:
                cur[1].append((m.group(1), plain(m.group(2))))
    return [g for g in groups if g[1]], described

# --- Collect sources ---------------------------------------------------------
pages = {}      # out path (relative to OUT_DIR, en file) -> dict
page_of = {}    # repo path -> site slug ("skills/ship")
warnings = []

def add_page(slug, lang, title, desc, source, body, kind):
    name = f"{slug}.md" if lang == "en" else f"{slug}.{lang}.md"
    pages[name] = dict(slug=slug, lang=lang, title=title, desc=desc,
                       source=source, body=body, kind=kind)

skills_dir = src("skills")
skill_names = sorted(d for d in os.listdir(os.path.join(ROOT, skills_dir))
                     if not d.startswith("_") and os.path.isdir(os.path.join(ROOT, skills_dir, d)))
skipped = []
for name in skill_names:
    rel = f"{skills_dir}/{name}/SKILL.md"
    if not os.path.isfile(os.path.join(ROOT, rel)):
        skipped.append(f"{name} (no SKILL.md)")
        continue
    meta, body = split_frontmatter(read(rel))
    _, body = strip_h1(body)
    page_of[rel] = f"skills/{name}"
    add_page(f"skills/{name}", "en", title_case(meta.get("name", name)),
             meta.get("description", ""), rel, body, "skill")

agents_dir = src("agents")
agent_names = sorted(f[:-3] for f in os.listdir(os.path.join(ROOT, agents_dir))
                     if f.endswith(".md") and os.path.isfile(os.path.join(ROOT, agents_dir, f)))
for name in agent_names:
    rel = f"{agents_dir}/{name}.md"
    meta, body = split_frontmatter(read(rel))
    _, body = strip_h1(body)
    page_of[rel] = f"agents/{name}"
    add_page(f"agents/{name}", "en", title_case(meta.get("name", name)),
             meta.get("description", ""), rel, body, "agent")

guides_dir = src("guides")
guide_names = sorted(f[:-3] for f in os.listdir(os.path.join(ROOT, guides_dir))
                     if f.endswith(".md") and os.path.isfile(os.path.join(ROOT, guides_dir, f)))
for name in guide_names:
    rel = f"{guides_dir}/{name}.md"
    h1, body = strip_h1(read(rel))
    page_of[rel] = f"agent-guides/{name}"
    add_page(f"agent-guides/{name}", "en", h1 or title_case(name),
             first_paragraph(body), rel, body, "guide")

wiki = src("wiki_payload")
module_order = []
for rel, slug in [(src("wiki_schema"), "wiki"), (src("html_schema"), "html-artifacts")]:
    h1, body = strip_h1(read(rel))
    page_of[rel] = f"modules/{slug}"
    add_page(f"modules/{slug}", "en", h1 or title_case(slug), first_paragraph(body), rel, body, "module")
    module_order.append(slug)
    if slug == "wiki":
        for d in sorted(os.listdir(os.path.join(ROOT, wiki, "skills"))):
            srel = f"{wiki}/skills/{d}/SKILL.md"
            if not os.path.isfile(os.path.join(ROOT, srel)):
                skipped.append(f"{d} (no SKILL.md)")
                continue
            meta, sbody = split_frontmatter(read(srel))
            _, sbody = strip_h1(sbody)
            page_of[srel] = f"modules/{d}"
            add_page(f"modules/{d}", "en", title_case(meta.get("name", d)),
                     meta.get("description", ""), srel, sbody, "skill")
            module_order.append(d)
        for f in sorted(os.listdir(os.path.join(ROOT, wiki, "agents"))):
            if not f.endswith(".md"):
                continue
            arel = f"{wiki}/agents/{f}"
            meta, abody = split_frontmatter(read(arel))
            _, abody = strip_h1(abody)
            page_of[arel] = f"modules/{f[:-3]}"
            add_page(f"modules/{f[:-3]}", "en", title_case(meta.get("name", f[:-3])),
                     meta.get("description", ""), arel, abody, "agent")
            module_order.append(f[:-3])

cl = src("changelog")
_, cl_body = strip_h1(read(cl))
page_of[cl] = "changelog"
for lang in LANGS:
    add_page("changelog", lang, CHANGELOG_TITLE[lang],
             "Every release of the kit, generated from Conventional Commits." if lang == "en"
             else "Todas as versões do kit, geradas a partir dos Conventional Commits.",
             cl, cl_body, "changelog")

# README → guide pages + anchor maps (one per language)
readmes = {"en": src("readme"), "pt-BR": src("readme_pt")}
anchor_map = {}   # (readme path, anchor) -> (slug, new_anchor or None)
groups_by_lang = {}
for lang, rel in readmes.items():
    sections = readme_sections(read(rel))
    by_emoji = {e: (h, b) for e, h, b in sections if e}
    for slug, emojis in GUIDE_PAGES:
        missing = [e for e in emojis if e not in by_emoji]
        if missing:
            sys.exit(f"gen-skill-docs: {rel} has no `## {missing[0]} …` section for guide/{slug}")
        parts, title, desc = [], None, ""
        for i, e in enumerate(emojis):
            head, body = by_emoji[e]
            text = strip_emoji(head)
            if i == 0:
                lead = next((l.strip() for l in body.splitlines() if l.strip()), "")
                title = text
                desc = "" if lead.startswith(("<", "#", "|")) else first_paragraph(body)
                anchor_map[(rel, gh_slug(head))] = (f"guide/{slug}", None)
                # the page's own H3s become its H2s
                body = re.sub(r"^(#{3,6}) ", lambda m: m.group(1)[1:] + " ", body, flags=re.M)
                level = 2
            else:
                anchor_map[(rel, gh_slug(head))] = (f"guide/{slug}", gh_slug(text))
                parts.append(f"## {text}")
                level = 3
            for m in re.finditer(r"^#{2,6} (.+)$", body, flags=re.M):
                anchor_map.setdefault((rel, gh_slug(m.group(1))), (f"guide/{slug}", gh_slug(m.group(1))))
            parts.append(details_to_headings(body, level))
        add_page(f"guide/{slug}", lang, title, desc, rel, "\n\n".join(parts), "readme")
    if SKILLS_SECTION not in by_emoji:
        sys.exit(f"gen-skill-docs: {rel} has no `## {SKILLS_SECTION} …` section")
    head, body = by_emoji[SKILLS_SECTION]
    anchor_map[(rel, gh_slug(head))] = ("skills", None)
    body = re.sub(r"^(#{3,6}) ", lambda m: m.group(1)[1:] + " ", body, flags=re.M)
    add_page("skills/index", lang, OVERVIEW[lang], first_paragraph(body), rel,
             details_to_headings(body, 2), "readme")
    groups_by_lang[lang] = skill_groups(body)

# Skills per language, in README group order. A skill no README group lists
# goes to "Other" with its intro-table description, and is reported.
skill_layout, ungrouped = {}, []
for lang in LANGS:
    groups, described = groups_by_lang[lang]
    layout, seen = [], set()
    for gname, rows in groups:
        rows = [(n, d) for n, d in rows if n in skill_names and n not in seen]
        if rows:
            layout.append((gname, rows))
            seen.update(n for n, _ in rows)
    rest = [(n, described.get(n, "")) for n in skill_names if n not in seen]
    if rest:
        layout.append((OTHER_GROUP[lang], rest))
        if lang == "en":
            ungrouped = [n for n, _ in rest]
    skill_layout[lang] = layout

# --- Link rewriting ----------------------------------------------------------
LINK = re.compile(r"(!?)\[((?:[^\[\]]|\[[^\]]*\])*)\]\(([^)\s]+)((?:\s+\"[^\"]*\")?)\)")
unlinked = []

def site_url(slug, lang, anchor=None):
    slug = re.sub(r"/index$", "", slug)
    url = f"/{lang}/docs/{slug}/"
    return url + (f"#{anchor}" if anchor else "")

def readme_target(readme_rel, frag, lang):
    hit = anchor_map.get((readme_rel, frag)) if frag else ("guide/why", None)
    if hit:
        return site_url(hit[0], lang, hit[1])
    return BLOB + readme_rel + (f"#{frag}" if frag else "")

def resolve(target, page):
    if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):
        return target
    path, _, frag = target.partition("#")
    source, lang = page["source"], page["lang"]
    if not path:
        if source in readmes.values():
            hit = anchor_map.get((source, frag))
            if hit is None:
                return BLOB + source + f"#{frag}"
            if hit[0] == page["slug"]:
                return f"#{hit[1]}" if hit[1] else "#"
            return site_url(hit[0], lang, hit[1])
        return target
    repo = os.path.normpath(os.path.join(os.path.dirname(source), path))
    if repo.startswith(".."):
        return None
    if repo in readmes.values():
        return readme_target(repo, frag, lang)
    if repo in page_of:
        return site_url(page_of[repo], lang, frag or None)
    full = os.path.join(ROOT, repo)
    if os.path.isdir(full):
        return TREE + repo
    if os.path.isfile(full):
        return BLOB + repo + (f"#{frag}" if frag else "")
    return None

def squeeze_blank_lines(body):
    out, fence = [], False
    for line in body.splitlines():
        if line.strip().startswith(("```", "~~~")):
            fence = not fence
        if not fence and not line.strip() and out and not out[-1].strip():
            continue
        out.append(line)
    return "\n".join(out)

def rewrite_links(body, page):
    out, fence = [], False
    for line in body.splitlines():
        if line.strip().startswith(("```", "~~~")):
            fence = not fence
            out.append(line)
            continue
        if fence:
            out.append(line)
            continue
        spans = [m.span() for m in re.finditer(r"`[^`]*`", line)]
        def fix(m):
            if any(a <= m.start() < b for a, b in spans):
                return m.group(0)
            bang, text, target, title = m.groups()
            if bang:
                if re.match(r"^[a-z]+:", target, re.I):
                    return m.group(0)
                repo = os.path.normpath(os.path.join(os.path.dirname(page["source"]), target))
                return f"![{text}]({RAW}{repo}{title})"
            new = resolve(target, page)
            if new is None:
                unlinked.append(f"{page['source']}: {target}")
                return text
            return f"[{text}]({new}{title})"
        line = LINK.sub(fix, line)
        out.append(line)
    return "\n".join(out)

# --- Render ------------------------------------------------------------------
def render(root):
    written = []
    for name, p in sorted(pages.items()):
        body = squeeze_blank_lines(rewrite_links(p["body"], p))
        path = os.path.join(root, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(front(p["title"], p["desc"], p["source"]) + body.rstrip() + "\n")
        written.append(name)

    def meta(folder, lang, pages_list, default_open=False):
        name = "meta.json" if lang == "en" else f"meta.{lang}.json"
        data = {"title": FOLDER_TITLES[folder][lang], "pages": pages_list}
        if default_open:
            data["defaultOpen"] = True
        with open(os.path.join(root, folder, name), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")

    for lang in LANGS:
        meta("guide", lang, [s for s, _ in GUIDE_PAGES], default_open=True)
        entries = ["index"]
        for gname, rows in skill_layout[lang]:
            entries += [f"---{gname}---"] + [n for n, _ in rows]
        meta("skills", lang, entries)
        meta("agents", lang, agent_names)
        meta("modules", lang, module_order)
        meta("agent-guides", lang, guide_names)
    for folder in FOLDER_TITLES:
        with open(os.path.join(root, folder, MARKER), "w"):
            pass

    hooks_dir = src("hooks")
    data = {
        "version": read(src("version")).split()[0],
        "counts": {
            "skills": len(skill_names),
            "moduleSkills": len([m for m in module_order if f"{wiki}/skills/{m}/SKILL.md" in page_of]),
            "hooks": len([f for f in os.listdir(os.path.join(ROOT, hooks_dir)) if f.endswith(".sh")]),
            "agents": len(agent_names),
            "templates": len([d for d in os.listdir(os.path.join(ROOT, src("examples")))
                              if os.path.isdir(os.path.join(ROOT, src("examples"), d))]),
        },
        "templates": sorted(d for d in os.listdir(os.path.join(ROOT, src("examples")))
                            if os.path.isdir(os.path.join(ROOT, src("examples"), d))),
        "skillGroups": {
            lang: [{"name": g, "skills": [{"name": n, "description": d} for n, d in rows]}
                   for g, rows in skill_layout[lang]]
            for lang in LANGS
        },
    }
    with open(os.path.join(os.path.dirname(root), "site-data.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return written, data

GENERATED = list(FOLDER_TITLES) + ["changelog.md", "changelog.pt-BR.md"]

def clear(root):
    for entry in GENERATED:
        path = os.path.join(root, entry)
        if os.path.isdir(path):
            if not os.path.exists(os.path.join(path, MARKER)):
                sys.exit(f"gen-skill-docs: {path} exists without a {MARKER} marker — not deleting a folder the generator didn't write")
            shutil.rmtree(path)
        elif os.path.isfile(path):
            os.remove(path)

def read_bytes(path):
    with open(path, "rb") as f:
        return f.read()

def snapshot(root):
    files = {}
    for entry in GENERATED + ["../site-data.json"]:
        path = os.path.normpath(os.path.join(root, entry))
        if os.path.isfile(path):
            files[entry] = read_bytes(path)
        for dirpath, _, names in os.walk(path) if os.path.isdir(path) else []:
            for n in names:
                p = os.path.join(dirpath, n)
                files[os.path.relpath(p, root)] = read_bytes(p)
    return files

if MODE == "dry-run":
    for name in sorted(pages):
        print(f"  [dry-run] {os.path.join(OUT_DIR, name)}")
    print(f"  {len(pages)} pages would be generated, {len(skipped)} skipped")
    sys.exit(0)

if MODE == "check":
    tmp = tempfile.mkdtemp()
    try:
        scratch = os.path.join(tmp, "content", "docs")
        os.makedirs(scratch)
        render(scratch)
        fresh, current = snapshot(scratch), snapshot(OUT_DIR)
        stale = sorted(k for k in set(fresh) | set(current) if fresh.get(k) != current.get(k))
    finally:
        shutil.rmtree(tmp)
    if stale:
        print(f"gen-skill-docs: {len(stale)} generated file(s) out of date — run ./scripts/gen-skill-docs.sh", file=sys.stderr)
        for k in stale[:20]:
            print(f"  {k}", file=sys.stderr)
        sys.exit(1)
    print("gen-skill-docs: generated pages are up to date")
    sys.exit(0)

os.makedirs(OUT_DIR, exist_ok=True)
clear(OUT_DIR)
written, data = render(OUT_DIR)
by_kind = {}
for p in pages.values():
    by_kind[p["kind"]] = by_kind.get(p["kind"], 0) + 1
kinds = ", ".join(f"{k} {v}" for k, v in sorted(by_kind.items()))
print(f"gen-skill-docs: generated {len(written)} ({kinds}) · skipped {len(skipped)}"
      + (f" ({'; '.join(skipped)})" if skipped else "")
      + f" · unlinked {len(unlinked)}"
      + f" · ungrouped {len(ungrouped)}")
for n in ungrouped:
    print(f"  ungrouped: /{n} is in no README skill group — listed under Other")
for u in sorted(set(unlinked)):
    print(f"  unlinked: {u}")
PY
