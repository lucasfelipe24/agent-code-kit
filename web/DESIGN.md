# DESIGN.md — agent-code-kit docs site

The design source of truth for `web/`. `/design-review` compares the built site
against this file. The kit's root `DESIGN.md` is the blank template the kit
installs into projects, so it does not describe this site.

## Visual Theme & Atmosphere

The site presents an engineering spec sheet for a guardrail system. It should
feel calm, exact and a little severe, like reading a well-kept runbook. What
the kit does that nothing else does is stop the agent at the right moment, so
the one loud element on the site is a real hook blocking an action. Everything
around that element stays quiet.

Dark-first, on the navy of the logo. The light theme is a full equal, not an
afterthought.

## Color Palette & Roles

| Role | Dark | Light | Usage |
|---|---|---|---|
| Ink (background) | `#0a1433` | `#f5f7fe` | Page background |
| Surface | `#101c44` | `#ffffff` | Terminal, code blocks, sidebar |
| Line | `#22306a` | `#d9dff2` | Borders, rules, dividers |
| Text | `#e7ecfb` | `#0b1a4a` | Body and headings |
| Text muted | `#9aa6cc` | `#4b5a86` | Descriptions, secondary text |
| Signal (primary) | `#4f8cff` | `#2459d6` | Links, active nav, primary button |
| Pass | `#22c1ee` | `#0879a6` | A check that passed, "allowed" lines |
| Block | `#f5b544` | `#a15c00` | A hook that blocked. Used only for this. |
| Focus | `#8b7dff` | `#5b4ae6` | Keyboard focus ring (violet from the logo) |

The logo's navy → blue → cyan ramp appears in one place only: the thin
progress track of the loop diagram. No gradient washes, no glow.

## Typography Rules

Families: **IBM Plex Sans** (body and UI), **IBM Plex Sans Condensed**
(display headings) and **IBM Plex Mono** (commands, transcript, code). All
three load via `next/font/google`.

| Element | Font | Size | Weight | Line height |
|---|---|---|---|---|
| Display (hero) | Plex Sans Condensed | `clamp(2.5rem, 5vw, 4rem)` | 600 | 1.02, tracking -0.02em |
| H2 (landing) | Plex Sans Condensed | `clamp(1.75rem, 3.5vw, 2.5rem)` | 600 | 1.1 |
| H3 | Plex Sans | 1.125rem | 600 | 1.3 |
| Body | Plex Sans | 1rem (landing lead 1.125rem) | 400 | 1.6 |
| Small | Plex Sans | 0.875rem | 400 | 1.5 |
| Code | Plex Mono | 0.875rem | 400 / 500 | 1.6 |

- Measure: 68ch or less for prose.
- Sentence case everywhere. No all-caps labels, no eyebrows above headings.
- Headlines use no accented word: no single word in a different color, italic or
  weight.
- Mono is used for literal things only: commands, file paths, transcript lines
  and skill names such as `/debug`. It is never used for decorative labels.

## Component Stylings

- **Transcript** (hero): a Surface panel with a 1px Line border and 10px
  radius. Mono text. Prompt lines are prefixed `›`. A blocked hook shows a
  4px Block-colored left rule and its real message
  (`BLOCKED by protect-changes.sh: …`). It plays once on load (see Motion) and
  then stays still.
- **Command box**: mono text on Surface, with a copy button at the right. The
  button's label reads `Copy` and becomes `Copied` for 2s.
- **Loop diagram**: four nodes on one horizontal track (vertical on mobile),
  numbered 1–4 because the content is a sequence. Verify's return arc back to
  Plan is drawn. Under each node, one line says what enforces it: *rule*
  (advisory) or *hook* (deterministic).
- **Skill index**: grouped lists that follow the README's groups (Plan, Build
  and debug, Review and audit, Ship, Memory and reports, Project setup). Each row is
  `/skill-name` in mono followed by a one-line description, and the whole row
  is a link. Rows are divided by rules, not boxed into cards.
- **Buttons**: primary is Signal fill with Ink text, 8px radius. Secondary is a
  1px Line border with Text. No arrows appended to labels.
- **Docs**: the Fumadocs layout, recolored through its `--color-fd-*`
  variables to this palette and set in these fonts. Callouts keep Fumadocs'
  semantic colors.

## Layout Principles

- Left-aligned throughout. Nothing is centered except the final install CTA's
  command box.
- Max content width 1120px; 24px gutters on mobile, 32px on desktop.
- The hero is two equal columns (copy left, transcript right) and stacks
  on mobile with the transcript second.
- Section rhythm: 96px between landing sections on desktop, 64px on mobile.
  Sections are separated by space, not by rules.

```text
┌──────────────────────────────────────────────────────────┐
│ logo  Docs  GitHub                      search  theme    │
├───────────────────────┬──────────────────────────────────┤
│ Headline (condensed)  │ ┌ transcript ──────────────────┐ │
│ lead                  │ │ › add search to users page   │ │
│ [npx … init   Copy]   │ │ Read CODEBASE_MAP.md … ?     │ │
│ Read the docs         │ │ ▌BLOCKED by protect-changes  │ │
│                       │ └──────────────────────────────┘ │
├───────────────────────┴──────────────────────────────────┤
│ The loop   (1)──(2)──(3)──(4) ↺                          │
│ One-sentence counts line                                  │
│ Skill index (2 columns of grouped rows)                   │
│ Stack templates (inline list)                             │
│ Install: npx │ curl tabs + command box                    │
└──────────────────────────────────────────────────────────┘
```

## Depth & Elevation

Flat. Elevation comes from Surface against Ink and a 1px Line border, never
from shadows. The search dialog and popovers keep the Fumadocs defaults.

## Motion

There is one orchestrated moment: the hero transcript. Its lines appear in
sequence over about 2.5s, the Block line arrives last, and then the transcript
stops. Nothing loops. With `prefers-reduced-motion`, the final state renders
immediately. No scroll-triggered reveals and no hover lift on rows. Hover only
changes the color of links and rows.

## Do's and Don'ts

- Do use the kit's real output (hook messages, commands, file names) as
  content. Never invent product claims.
- Do read counts (skills, hooks, agents, templates) from the generated tree at
  build time. Never hard-code them.
- Don't use Roman numerals, a two-column before/after block or live GitHub
  stats. Those belong to the reference site.
- Don't use gradient washes, glows, or the same card for every item.
- Don't use middle-dot meta strings (`a · b · c`) or `→` after link text.

## Responsive Behavior

- Below 768px the hero stacks, the loop becomes vertical, and the skill index
  becomes one column.
- Tap targets are at least 44px tall. Command boxes scroll horizontally rather
  than wrap. Accepted exception: Fumadocs' own header controls (search, theme,
  language, GitHub) are 32–36px, above WCAG 2.2's 24px minimum.
- The docs home lists its entry points as a plain list, not cards.
- Test at 360, 768 and 1280px.

## Accessibility

WCAG 2.2 AA. Text and background pairs above meet 4.5:1 (check Muted on
Surface in both themes). A visible 2px Focus ring with 2px offset on every
interactive element. The transcript is a `<pre>`-like region with an
`aria-label`, and its animation is decorative, because the full text is
present in the DOM from the start.

## Agent Prompt Guide

When building a page or component for `web/`: read this file first, use the
tokens from `app/global.css` rather than raw hex, keep copy in the README's
voice (short sentences, second person, concrete commands), and check the
result with `/design-review` and `/accessibility-audit`.
