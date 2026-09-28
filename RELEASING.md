# RELEASING

How `@lucasfelipe23/agent-code-kit` ships, and what to do when a release fails. Read this before cutting a release.

## 1. Normal release

1. Merge work into `main` with squash — each pull request title becomes one Conventional Commit.
2. release-please keeps a pull request titled `chore(main): release X.Y.Z` open whenever `main` has unreleased `fix:` or `feat:` commits. It bumps the version in `package.json`, `VERSION`, `.release-please-manifest.json` and `.claude-plugin/`, and writes the changelog.
3. Review that pull request and merge it (squash). The Release workflow then creates the tag and the GitHub release, and publishes the package to npm.
4. Check the result:

   ```bash
   npm view @lucasfelipe23/agent-code-kit version
   npx --yes @lucasfelipe23/agent-code-kit@X.Y.Z --version
   ```

`docs:`, `chore:` and `test:` commits don't make a release on their own, and the npm package page only changes when one is published.

## 2. One-time setup

**npm scope.** The package scope has to be the npm username, `lucasfelipe23`. It differs from the GitHub owner, `lucasfelipe24`, on purpose (ADR-024): GitHub URLs keep `lucasfelipe24`, npm names keep `lucasfelipe23`.

**npm token.** Create a granular access token at `https://www.npmjs.com/settings/lucasfelipe23/tokens`:

- **Packages:** Read and write, with publish allowed, on the `@lucasfelipe23` scope (or on the package itself once it exists)
- **Bypass two-factor authentication:** on — CI can't answer an OTP prompt, and without it publishing fails with `EOTP`
- **Organizations:** none
- **IP allowlist:** none — GitHub-hosted runners have no fixed addresses
- **Expiry:** 90 days, with a reminder to rotate before it lapses

Keep two-factor authentication on for the account itself. Don't turn on the package setting "Require two-factor authentication and disallow tokens": it blocks every token, bypass or not.

Save the token as the `NPM_TOKEN` repository secret (GitHub → Settings → Secrets and variables → Actions). Paste it only into that form, or into `gh secret set NPM_TOKEN`, which prompts for it — never into a command line, chat or screenshot.

**GitHub Actions permission.** release-please opens its pull request with the workflow's token, which the repository has to allow: Settings → Actions → General → Workflow permissions → "Allow GitHub Actions to create and approve pull requests".

## 3. When a release fails

| Symptom | Cause | Fix |
|---|---|---|
| `GitHub Actions is not permitted to create or approve pull requests` | The Actions permission in §2 is off | Turn it on, then re-run the Release workflow |
| `404 Not Found - PUT https://registry.npmjs.org/@…` with `Scope not found` | The package scope isn't the token owner's npm username | Name the package `@lucasfelipe23/…` (§2) |
| `EOTP` / one-time password required | The token was created without "bypass two-factor authentication" | Create a new token with it (§2) and update `NPM_TOKEN` |
| `401` / `403` on publish | The token expired, was revoked, or doesn't cover this package | Create a new token (§2) and update `NPM_TOKEN` |
| A provenance error | The publish job lacks `id-token: write`, the repository isn't public, or `repository.url` in `package.json` doesn't point at it | Provenance needs all three; the workflow and `package.json` have them today (ADR-025) |

If publishing fails **after** the tag was created, fix the cause and re-run only the failed "Publish to npm" job of that same run. Don't start another release for it. The exception is a problem inside the tagged files themselves, such as a wrong package name: a tag can't change, so fix it on `main` and ship the next patch. That's what happened to 1.22.1, which exists only as a GitHub release; npm starts at 1.22.2.

**Publishing by hand**, when CI can't:

```bash
git fetch --tags
git switch --detach vX.Y.Z
npm login                              # browser sign-in
npm publish --access public            # asks for your OTP
git switch main
npm view @lucasfelipe23/agent-code-kit version
```

## 4. Token hygiene

If a token is ever exposed — in chat, logs, screenshots or terminal scrollback — revoke it at `https://www.npmjs.com/settings/lucasfelipe23/tokens` right away, create a new one and update `NPM_TOKEN`. Don't keep using a token that may have leaked, even if nothing looks wrong.

## 5. Before January 2027: move to trusted publishing

npm is removing direct publishing with bypass-2FA tokens in January 2027, so the `NPM_TOKEN` setup in §2 stops working then. The replacement is trusted publishing: GitHub Actions proves its identity to npm with a short-lived OIDC token and no secret is stored. Migrating means:

- on npmjs.com, add a trusted publisher to the package: GitHub owner `lucasfelipe24`, repository `agent-code-kit`, workflow file `release.yml`
- in the `publish-npm` job, use Node.js 22.14.0+ and npm 11.5.1+, and drop `NODE_AUTH_TOKEN` (the job already has `id-token: write`)
- delete the `NPM_TOKEN` secret and revoke the token

With the repository public, trusted publishing generates provenance on its own, so `--provenance` can come off the publish command then.

## 6. Plugin marketplace

release-please keeps the versions in `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json` in step with the package. The plugin route doesn't work yet: Claude Code looks for a plugin's skills in `skills/`, its agents in `agents/` and its hooks in `hooks/hooks.json` at the plugin root, and the kit keeps them under `.claude/` without pointing the manifest there. Installing the plugin loads none of them, so the README doesn't offer it.

---

## Sources

- npm access tokens — <https://docs.npmjs.com/about-access-tokens>
- Creating granular access tokens — <https://docs.npmjs.com/creating-and-viewing-access-tokens>
- Two-factor authentication for publishing — <https://docs.npmjs.com/requiring-2fa-for-package-publishing-and-settings-modification>
- Trusted publishing — <https://docs.npmjs.com/trusted-publishers>
- Provenance — <https://docs.npmjs.com/generating-provenance-statements>
