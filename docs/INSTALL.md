# Installing ship-kit on any agent

ship-kit's skills follow the open [Agent Skills](https://agentskills.io) standard: each
skill is a directory with a `SKILL.md` (YAML frontmatter + Markdown body) and the only
load-bearing frontmatter is `name` + `description`. Every major coding agent now reads this
format and auto-discovers skills from a scanned directory by matching the `description`.

The canonical skills live in this repo at **`.agents/skills/<name>/SKILL.md`** — the
emerging cross-client convention with the widest reach. `bin/install.sh` copies them into
whatever directory your agent scans.

> Already installed? Jump to **[USAGE.md](USAGE.md)** for how to drive the kit.

## Compatibility matrix

| Agent | Skills dir it scans | Install command | Invocation |
|-------|--------------------|-----------------|------------|
| **Claude Code** | plugin `skills/`, `~/.claude/skills`, `.claude/skills` | `/plugin marketplace add nsollazzo/ship-kit` → `/plugin install ship-kit` (or `bin/install.sh claude`) | auto by description + `/ship` etc. |
| **OpenAI Codex** | `.agents/skills` (repo), `~/.agents/skills` (user) | `bin/install.sh agents` | implicit (description) + `$ship` |
| **xAI Grok Build** (official) | `.grok/skills`, `~/.grok/skills`, **and reads Claude plugins/`.claude/skills` with zero config** | `bin/install.sh grok` (or just use the Claude plugin) | auto + `/ship` |
| **Grok CLI** (community) | `.agents/skills`, `~/.agents/skills` | `bin/install.sh agents` | auto (reads skill on demand) |
| **Nous Hermes** | `~/.hermes/skills/<category>/<name>` | `hermes skills tap add nsollazzo/ship-kit` (native), or `bin/install.sh hermes` (local) | auto + `/ship` slash commands |
| **OpenClaw** | `<workspace>/skills`, `~/.agents/skills`, `~/.openclaw/skills` | `bin/install.sh openclaw` (or `agents`) | auto + slash command |
| **VS Code / Copilot** | `.github/skills`, `.claude/skills`, `.agents/skills`, `~/.copilot/skills` | `bin/install.sh agents` (VS Code → `~/.agents/skills`) **or** `copilot` (Copilot CLI → `~/.copilot/skills`) — different dirs, pick the one your client scans | `/skill-name` |

`bin/install.sh all` installs into every one of these whose home directory already exists
under `$HOME`. `bin/install.sh --project` drops the skills into the current repo's
`.agents/skills/` so an agent working in that repo discovers them in-tree.

## Per-agent notes

### Claude Code
The repo is a plugin marketplace. `marketplace.json` (at the repo root) points its one
plugin's `source` at `./.agents`, so Claude reads the canonical `.agents/skills/` tree
directly — no separate copy. After `/plugin install ship-kit` the skills auto-trigger by
description, and are available as **plugin-namespaced** slash commands: `/ship-kit:ship`,
`/ship-kit:babysit`, `/ship-kit:smart-commit`, `/ship-kit:reflect`, plus the bundled
`/ship-kit:simplify` / `/ship-kit:verify` / `/ship-kit:code-review` (Claude Code prefixes
plugin skills with the plugin name, so bare `/ship` is not guaranteed). On Claude, `ship`
prefers the **built-in** `simplify`/`verify`/`code-review` (richer — `code-review` has a
cloud `ultra` mode) over the bundled fallbacks.

**Releasing (maintainer note):** the plugin's effective version pin is
`.agents/.claude-plugin/plugin.json` → `version` (it wins over the marketplace entry).
Bump *that* on every release — pushing commits without bumping it means installed users
get no update. Keep `.claude-plugin/marketplace.json` → `metadata.version` in lockstep.

### OpenAI Codex
Codex reads only `name` + `description` from `SKILL.md`; everything else is ignored (tool
policy would live in an optional `agents/openai.yaml` sidecar, which ship-kit doesn't need).
Skills land in `~/.agents/skills/` (user) or a repo's `.agents/skills/`. Invoke implicitly
by description or explicitly with `$ship`. Codex has no structured "ask the user" tool —
ship's one checkpoint degrades to a plain-text "proceed? (yes/no)" which Codex handles in
interactive mode (in `codex exec` non-interactive mode it stops and reports "staged and
waiting", as designed).

### xAI Grok
- **Grok Build (official)** is "compatible with Claude Code with zero configuration" — it
  reads Claude plugins, `.claude/skills`, and `CLAUDE.md` directly. You can install via the
  Claude plugin path *or* `bin/install.sh grok` (→ `~/.grok/skills`).
- **Grok CLI (community, superagent-ai)** scans `.agents/skills` — use `bin/install.sh agents`.

### Nous Hermes
Two ways in:

- **Native Tap (recommended)** — `hermes skills tap add nsollazzo/ship-kit`. Hermes' Tap
  scanner reads a **flat** `skills/<name>/SKILL.md` tree at the repo root (verified against
  hermes-agent's `skills_hub.py`: depth-1, directory name is the install slug). ship-kit
  ships exactly that tree at `skills/`, generated from canonical `.agents/skills/` by
  `bin/build-adapters.sh`, plus a `skills.sh.json` that labels them under a "ship-kit"
  category in the Skills Hub. Plain `name`/`description`/`license` frontmatter loads as-is —
  no Hermes-specific fields needed. (Caveat: hermes-agent issue #14466 means Tap'd skills may
  not show under `hermes skills search` yet; `hermes skills tap list` and
  `hermes skills install nsollazzo/ship-kit/skills/<name>` work regardless.)
- **Local copy** — `bin/install.sh hermes` places them under `~/.hermes/skills/ship-kit/<name>/`
  (the local store IS category-nested, so "ship-kit" becomes the category).

Hermes' own equivalents for the harness features ship rewrote away: `clarify` (ask the
user), `delegate_task` (subagents), `cronjob`/`blueprint` (the loop primitive). Skill bodies
are read as prose the agent follows, so the generic wording works without Hermes tool names.

### OpenClaw
OpenClaw reads `SKILL.md` (name + description) and gates via `metadata.openclaw` — ship-kit
needs none of that. Install to `~/.openclaw/skills`, `~/.agents/skills`, or the workspace
skills dir. Note OpenClaw delegates actual coding to an external CLI (Claude/Codex/OpenCode),
so ship-kit's git/PR skills run there; OpenClaw's own subagent analog is `sessions_spawn`.

## What "portable" required (design)

A Claude-Code skill assumes things other harnesses lack. ship-kit was generalized to avoid
all of them:

1. **No skill-invokes-skill tool dependency.** Only Claude Code has a callable `Skill`
   dispatcher. `ship` names each stage's skill and says: call it if your harness has a
   skill tool, otherwise *load and follow that skill's `SKILL.md`*. Because the dependencies
   (`simplify`/`verify`/`code-review`) are **bundled in the same kit**, "follow the bundled
   skill" works everywhere.
2. **No `AskUserQuestion`.** ship's single checkpoint and reflect's approval step are plain
   "ask in chat and wait" — degrading to text on agents without a structured prompt
   (Hermes `clarify`, Codex approval overlay, OpenClaw channel message all satisfy it).
3. **No assumed loop runtime.** `babysit`'s "loop until green" uses your harness's recurring
   primitive if it has one (Claude `loop`, Hermes cron/blueprint) and otherwise iterates
   in-session.
4. **No Claude-only packaging requirement.** Distribution is "drop the skill directory into
   a scanned skills dir." The Claude marketplace is one adapter, not the only path.
5. **Frontmatter hygiene.** Only `name` + `description` are load-bearing; `license: MIT` is
   included (some Copilot CLI versions erroneously require it); multi-line descriptions use
   YAML block scalars (`|`) so a `:` in the text never trips a strict parser.

## Troubleshooting

- **Skill doesn't auto-trigger.** Discovery is description-driven. Make sure the install
  landed in a directory your agent actually scans (see the matrix) and restart the session
  so the catalog reloads.
- **GitHub Copilot CLI rejects a skill without `license`.** ship-kit already sets
  `license: MIT` in every skill, so this known bug doesn't apply here.
- **`gh` steps fail.** `babysit` and `ship`'s PR stages need `gh` authenticated
  (`gh auth status`) against a GitHub remote. They are git/`gh`-based, not harness-specific.
- **Two of the same skill on Claude Code.** Bundled skills are plugin-namespaced
  (`ship-kit:code-review`) and do not override Claude's built-in `/code-review`; `ship`
  deliberately prefers the built-in there.
