# References: docs-site

## Codebase

- `scripts/gen-skill-docs.sh`: the existing Fumadocs generator (skills +
  `--agents`), extended by this feature
- `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`, `agent_docs/*.md`: the
  generated pages' sources
- `wiki-module/.claude/`, `WIKI.md`, `ARTIFACTS.md`, `html-module/`: module
  pages
- `.claude/settings.json`: hook events and matchers for the hooks reference
- `README.md` / `README.pt-BR.md`: source and voice for the hand-written pages
- `assets/logo.png`: brand palette
- `examples/*/`: stack templates listed on the landing
- `.github/workflows/validate.yml`, `release.yml`: CI conventions (action
  versions, job naming)
- `scripts/check-prefix-residue.sh`: forbids the former prefix in tracked
  content
- `tasks/decisions.md` ADR-009 (homepage → docs site), ADR-031/035 (R2 layout
  moves that change the generator's source paths)

## Skills

- `frontend-design:frontend-design`: aesthetic direction, written into
  `web/DESIGN.md`
- `/ui-component-builder`: each landing section component (states, a11y,
  responsive)
- `/design-review`: the built UI compared against `web/DESIGN.md`
- `/accessibility-audit`: WCAG 2.2 AA over the landing and the docs layout
- `/documentation-audit`: quality and concision of the hand-written pages
- `/web-read`: extracts the reference pages (Defuddle)
- `/verification-status`: records the smoke test and generator counts
- `/review-pipeline`, then `/ship`: review of the diff and the PR

## External

- <https://claudecodekit.tansuasici.com/> and `/docs`: scope reference (not
  design)
- <https://fumadocs.dev/docs>: Fumadocs (core/ui 16, mdx 15), i18n, static
  search, static export
- <https://nextjs.org/docs/app/guides/static-exports>: `output: 'export'`,
  `basePath`
- <https://github.com/actions/deploy-pages>: Pages deployment from Actions
