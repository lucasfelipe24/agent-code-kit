# Feature: docs-site

> Steps 3–5 were refined during implementation: see `shape.md` Decisions 8–10
> (guide pages generated from the READMEs, README skill groups, npx and curl
> install tabs only). Where this plan and `shape.md` differ, `shape.md` wins.

## Goal

`https://lucasfelipe24.github.io/agent-code-kit/` serves a landing page and a
searchable docs tree in English and pt-BR. CI builds it from the kit's own
sources on every push to `main`. Done means all of these checks pass:

1. `bash scripts/gen-skill-docs.sh` (new default `--out web/content/docs`)
   writes one page per skill, agent and kit doc plus the sidebar `meta.json`
   files, and ends with `generated N · skipped S (reasons)`. N equals the live
   count of skills + agents + `agent_docs/*.md`. S is 0 on a clean tree.
2. `cd web && npm ci && npm run build` produces a static `web/out/` without
   errors. Every generated page is in it under `/en/docs/…` and
   `/pt-BR/docs/…`, and pt-BR falls back to the English body when no
   translation exists.
3. A link check over `web/out/` finds no broken internal link, including the
   links the generator rewrote from repo paths (`agent_docs/workflow.md`,
   `.claude/skills/x/SKILL.md`, …).
4. Smoke test: `web/out` served under `/agent-code-kit`. The landing page loads,
   search (static index) finds "quality-gate", and the language switch and the
   theme toggle both work.
5. `.github/workflows/pages.yml` deploys on push to `main` and only builds on
   PRs that touch `web/`, the generator or a source. The kit's `npm run check`
   and `npm test` stay green, and nothing under `web/` reaches `.kit-manifest`,
   the npm `files` list or an install.
6. `/design-review` against `web/DESIGN.md` and `/accessibility-audit` (WCAG 2.2
   AA) report no open high-severity finding. `/documentation-audit` over the
   hand-written pages reports none either.

## Context

`scripts/gen-skill-docs.sh` already emits Fumadocs MDX, but into
`../web/content/docs`, a sibling directory with no site project in it. The
kit has no public docs besides the README. `package.json` `homepage` and
`.claude-plugin/plugin.json` point at the GitHub README, although ADR-009
intended a docs site there. The upstream reference
(claudecodekit.tansuasici.com) sets the scope, not the design. The
maintainer's answers (2026-09-30) are recorded in `shape.md`.

## Approach

Each step names the kit skill that drives or checks it.

1. **Design direction** (`frontend-design:frontend-design`). Write
   `web/DESIGN.md`, the site's design source of truth: palette from
   `assets/logo.png`, typography, spacing, the component inventory and the
   landing's section list. The root `DESIGN.md` is the kit's shipped blank
   template and stays untouched.
2. **Scaffold `web/`.** Next 16 App Router, fumadocs-core/ui 16, fumadocs-mdx
   15 and Tailwind 4, with its own `package.json` and lockfile. Set
   `output: 'export'`, `basePath: '/agent-code-kit'`, `images.unoptimized` and
   `trailingSlash`. Use Fumadocs i18n (`en` default, `pt-BR`) with
   `hideLocale: 'never'`. `/` is a static page that redirects by browser
   language and falls back to `/en/`. Search uses a static Orama index per
   locale (`staticGET` + client `type: 'static'`). Before step 3 relies on it,
   check that fumadocs-mdx compiles generated `.md` as plain markdown for every
   current source.
3. **Extend the generator** (`scripts/gen-skill-docs.sh`):
   - Put the source paths in one table at the top of the script, trying the R2
     path first and the current path second, so the script keeps working while
     R2 lands its moves PR by PR.
   - Emit `.md`, not `.mdx`, because kit markdown carries `<`, `{}` and HTML
     comments that MDX rejects. Quote the frontmatter with a real escape.
   - Build the sidebar sections: Skills split into Audit / Workflow / Meta by a
     fixed table (a skill missing from the table fails the run), then the Wiki
     and HTML modules, Agents, Guides (`agent_docs`) and Reference (the hooks
     table from `settings.json`, scripts, changelog). Write each folder's
     `meta.json`.
   - Rewrite links: a repo-relative link to a generated source becomes the site
     link, and any other repo path becomes a GitHub `blob/main` URL.
   - Add a `--check` mode, the counts line, and a non-zero exit on any skip
     that has no reason.
4. **Hand-written docs pages** (`web/content/docs/*.mdx`, committed, EN +
   pt-BR): Introduction, Quick start, How it works, Workflows and FAQ. Take the
   content from `README.md` / `README.pt-BR.md` and cut it down rather than
   rewrite it, keeping the README's voice: short sentences, second person,
   concrete commands. Generated pages live in a gitignored `(generated)` folder
   so they never share a folder with hand-written pages. Checked by
   `/documentation-audit`.
5. **Landing page** (`/ui-component-builder` for each section component:
   states, a11y, responsive). The hero has the `npx` command and a copy button.
   Then a session transcript shows a hook blocking an action, using the kit's
   real BLOCKED output. Then the loop (Plan → Confirm → Implement → Verify)
   appears as a connected diagram. Then counts read at build time from the
   generated tree, the skill grid by category, the stack templates, and the
   install CTA. Out of scope, because they are the reference site's
   signatures: Roman-numeral sections, a two-column before/after, and a live
   GitHub stats widget.
6. **CI** (`.github/workflows/pages.yml`): checkout, then
   `gen-skill-docs.sh`, then `npm ci` and `npm run build` in `web/`, then
   `lychee --offline` on `web/out`, then `upload-pages-artifact` and
   `deploy-pages` on `main` only.
7. **Wiring**: add `web/` build outputs and the generated folder to
   `.gitignore`. Point `homepage` in `package.json` and
   `.claude-plugin/plugin.json` at the site. Add a docs link to both READMEs.
   Update `CODEBASE_MAP.md` and the local preview commands in
   `CONTRIBUTING.md`.
8. **Verify and review**: run the checks in Goal 1–5, then `/design-review`,
   `/accessibility-audit` and `/documentation-audit` (Goal 6).
   `/verification-status` records the smoke test and counts. Then
   `/review-pipeline` over the diff and `/ship` for the PR.

## Files to Touch

- `web/**` (new): `package.json`, lockfile, `next.config.mjs`,
  `source.config.ts`, `app/`, `lib/`, `components/`, `content/docs/`
  hand-written pages, `DESIGN.md`
- `scripts/gen-skill-docs.sh`: default out dir, path table, `.md` output,
  sections + `meta.json`, link rewrite, `--check`, counts line
- `.github/workflows/pages.yml` (new)
- `.gitignore`; `package.json` and `.claude-plugin/plugin.json` (`homepage`
  only)
- `README.md`, `README.pt-BR.md`, `CODEBASE_MAP.md`, `CONTRIBUTING.md`: links
  and the map
- `tasks/decisions.md`: ADR-036. `tasks/todo.md`: a pointer to this spec.

## Open Questions

- None blocking. One manual step for the maintainer at merge time: enable
  Settings → Pages → Source = GitHub Actions.

## Risks

- **R2 moves the sources mid-flight.** The path table with fallbacks covers
  this. Whichever of the R2 moves PRs and this PR lands second updates the
  table. ADR-031 already lists `gen-skill-docs.sh` as a changing site.
- **`.md` through fumadocs-mdx.** If a kit doc still breaks the build (raw
  HTML, for example), the generator escapes it or the build fails loudly. A
  page is never dropped silently. Step 2 measures this on every current source.
- **basePath leaks.** Hard-coded `/docs` links or `<img src="/…">` break on
  Pages. The link check runs against `web/out` with the base path.
- **Former-prefix residue** (`check-prefix-residue.sh`, ADR-029) scans tracked
  content, so no upstream name or URL goes into the site's files under `web/`.
  The reference URL is cited only in this spec, as a scope source.
- **ADR number collision** with R2: renumber on rebase if needed.

## Not Now

- pt-BR bodies for generated pages (skills/agents/guides stay English, since
  they are the kit's sources)
- Custom domain / CNAME
- Interactive skill explorer, recipes section, OG image generation
