---
description: Security-scan, then push to GitHub, update README, repo About, and GitHub Pages (via Actions). Usage - /publish <repo URL or owner/name> [visibility]
argument-hint: <github repo url or owner/name> [public|private]
allowed-tools: Bash, PowerShell, Read, Write, Edit, Glob, Grep
---

Publish this project to GitHub. Repo details from the user: `$ARGUMENTS`

If `$ARGUMENTS` is empty or the repo can't be determined (need `owner/name`), ask the user for it and stop. Accept a full URL, `owner/name`, or SSH form; normalize to `owner/name`.

Work through the phases in order. **Phase 1 is a hard gate: nothing leaves the machine until it passes and the user approves.**

## Phase 1: Security scan (before anything touches the internet)

Scan every file that would be pushed (tracked files, plus untracked files not ignored: use `git ls-files --cached --others --exclude-standard`). Also scan git history (`git log -p --all`) for the same patterns, since pushing publishes history too.

Check for:
1. **Secrets**: API keys, tokens (`ghp_`, `github_pat_`, `AKIA`, `sk-`, `xox[bp]-`), private keys (`-----BEGIN ... PRIVATE KEY-----`), passwords, `.env` files, credentials in URLs, high-entropy strings assigned to key/secret/token variables.
2. **Personal data**: the user's email address (from the userEmail context) and any other email/phone numbers. Per CLAUDE.md the email may only appear where FormSubmit requires it. If it is in `FORMSUBMIT_ENDPOINT`, report it explicitly: a public repo exposes it. Recommend using FormSubmit's random-alias endpoint instead of the plain email, and ask the user how to proceed.
3. **Git metadata**: author/committer emails in `git log --format='%ae %ce'`. If a real email is present, warn the user and suggest the GitHub noreply address (`<id>+<user>@users.noreply.github.com`) for future commits. Do not rewrite history without explicit approval.
4. **Junk that shouldn't be published**: IDE folders (`.idea/`, `.vscode/`), `.claude/settings.local.json`, OS files, `node_modules`, logs, large binaries. Ensure a `.gitignore` covers them; create or update it if needed.
5. **Code issues relevant to a public web page**: `eval`, unescaped `innerHTML` with user input (CLAUDE.md requires `escapeHtml()`), external script/CDN includes (forbidden by CLAUDE.md), inline secrets in the HTML/JS.
6. **Workflow safety** (re-check after Phase 4): the Actions workflow uses minimal `permissions`, pinned official actions, and no secrets.

Report findings as a table: severity, file:line, issue, recommended fix. Fix what is safe to fix automatically (e.g. `.gitignore`). For anything else, show the findings and use AskUserQuestion to get a go/no-go. **If any High finding is unresolved, stop.** Never print a full secret value in output; mask it.

## Phase 2: Repo setup and push

1. Verify tooling: `git --version`, `gh --version`, `gh auth status`. If `gh` is missing or unauthenticated, tell the user to run `! gh auth login` and stop.
2. Check whether the repo exists: `gh repo view <owner/name>`. If it doesn't, confirm with the user (visibility: use the second argument, else ask; default private is safest), then `gh repo create`. GitHub Pages on a free account needs a public repo; mention this if they choose private.
3. Confirm the default branch (`main`). Set `origin` to the repo (HTTPS URL) if missing; if `origin` points elsewhere, ask before changing it.
4. Stage only scanned, intended files (never `git add -A` blindly; review `git status` first). Commit with a clear message ending with the required co-author trailer. Do not use `--no-verify`.
5. Show the user the exact push target and commit list, get confirmation, then `git push -u origin main`. Never force-push.

## Phase 3: Screenshot and README

**Screenshot (Playwright MCP).** Capture the running board before writing the README:
1. Load the Playwright MCP tools (`mcp__playwright__*`, configured in `.mcp.json`) with ToolSearch. If they are unavailable, tell the user to restart Claude Code and approve the project MCP server, skip the screenshot, and say so in the final report. Do not substitute another tool silently.
2. `browser_navigate` to the local file URL of `index.html` (`file:///<absolute path>/index.html`), set a desktop viewport (about 1440x900) with `browser_resize`, and confirm the cards rendered (`browser_snapshot`).
3. `browser_take_screenshot` (PNG, full page) and save it as `docs/screenshot.png`, creating `docs/` if needed. Look at the image to confirm it shows the populated board, and make sure it contains no real personal data (the board uses seeded fictitious data only).
4. Close the browser with `browser_close`. Commit `docs/screenshot.png` with the README; it is not part of the Pages artifact, only the repo.

**README.** Create or edit `README.md` (preserve any existing hand-written content; update rather than overwrite). Base it on the actual code in `index.html` and CLAUDE.md, not guesses. Include:
- Title and one-line description (IT PMO Kanban board demo for a fictitious bank)
- Live demo link: `https://<owner>.github.io/<repo>/`
- The screenshot, near the top: `![IT PMO Kanban board](docs/screenshot.png)` (omit if the screenshot was skipped)
- Features (columns, drag and drop, filters, overdue logic, add task with FormSubmit notification)
- How to run locally (open `index.html`, no build or server)
- Constraints/notes: vanilla HTML/CSS/JS, no persistence (refresh resets to seeded data), no external dependencies
- Tech stack and project structure
- A short disclaimer that the bank and data are fictitious and not affiliated with any real institution

Do not include the user's email or any endpoint token. Commit and push README changes.

## Phase 4: GitHub Pages via GitHub Actions

Create or update `.github/workflows/pages.yml` using the official Pages actions:
- Triggers: `push` to `main` and `workflow_dispatch`
- `permissions`: `contents: read`, `pages: write`, `id-token: write`
- `concurrency` group `pages`, `cancel-in-progress: false`
- Job `build` (or a single job): `actions/checkout`, `actions/configure-pages`, `actions/upload-pages-artifact` with a `path` that contains only the publishable files (copy `index.html` into a `_site` dir first so `.git`, `.claude`, and `.idea` are never uploaded), then a `deploy` job using `actions/deploy-pages` with the `github-pages` environment
- Use current major versions of the official actions (verify the latest with `gh api repos/actions/<name>/releases/latest --jq .tag_name` rather than guessing)

Then enable Pages with the Actions source:
`gh api -X POST repos/<owner>/<repo>/pages -f build_type=workflow` (if it already exists, use `-X PUT`). Commit and push the workflow, then watch the run (`gh run watch`) and confirm it succeeded. If it fails, read the logs (`gh run view --log-failed`), fix, and retry. Finally verify the URL responds (`gh api repos/<owner>/<repo>/pages --jq .html_url`, then a HEAD request).

## Phase 5: Repo About

Set the description, homepage, and topics:
```
gh repo edit <owner/name> \
  --description "Kanban-style IT PMO project board demo for a fictitious bank. Vanilla HTML/CSS/JS, single file, no build." \
  --homepage "https://<owner>.github.io/<repo>/" \
  --add-topic kanban --add-topic project-management --add-topic pmo --add-topic vanilla-javascript --add-topic single-file --add-topic github-pages --add-topic demo
```
If the repo already has a description or topics, show what's there and keep or merge instead of clobbering.

## Final report

Summarize in a few lines: scan result (and anything the user accepted), repo URL, Pages URL and deploy status, README/About changes. List anything skipped or needing user action. State failures plainly.
