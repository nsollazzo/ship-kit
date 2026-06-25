# ship-kit

A portable agent-skills bundle for the whole dev loop: turn a **reported bug** into a fix, or
a **finished change** into a green, mergeable pull request — and keep the PR honest until a
reviewer approves it.

ship-kit's skills follow the open [Agent Skills](https://agentskills.io) standard
(`SKILL.md`), so the **same kit installs on any compatible agent** — Claude Code, OpenAI
Codex, xAI Grok, Nous Hermes, OpenClaw, VS Code / Copilot, and more. It bundles everything
it needs, so it does **not** rely on skills being pre-installed by the host.

## What's inside

| Skill | What it does |
|-------|--------------|
| `fix` | The inbound headliner: **triage → branch → implement → ship.** Diagnoses a reported bug, cuts a `fix/…` branch, implements the fix at the root cause, then hands off to `ship` for the whole way to a green PR. Pass `--yolo` to run hands-off. |
| `ship` | The outbound headliner: **simplify → verify → code-review → smart-commit → branch hygiene → PR → babysit → reflect.** Stops at *approved + CI green + mergeable*; only merges with `--merge`. |
| `triage` | Diagnoses a bug with **parallel sub-agents** across different angles (reproduce, recent changes, backward root-cause trace, blast-radius), adversarially verifies the leading cause, and proposes the fix — **read-only**, never edits code. `fix` is the applier. |
| `babysit` | Drives one GitHub PR to a **fresh APPROVED + all CI green + `mergeable`** state. Each pass verifies every review finding against the code, fixes the valid ones, pushes back with evidence on the invalid, and replies on every thread. Never merges — a human does that. |
| `smart-commit` | Clusters uncommitted changes into logical groups and commits each with a conventional-commit message. |
| `reflect` | Captures session lessons (gotchas, patterns, integration quirks) into the knowledge base. Self-gating, never writes without your approval. Runs as `ship`'s final step. |
| `simplify` | Quality-only cleanup pass (reuse / simplification / efficiency) over a change. **Bundled** so `ship` works without a pre-installed simplifier. |
| `verify` | Runs the project's tests / app and observes the change actually working. **Bundled.** |
| `code-review` | Reviews a diff for correctness bugs **and** cleanups, then applies fixes (`--fix`) or posts inline PR comments (`--comment`). **Bundled.** |
| `yolo` | Autonomous, hands-off mode: never asks, resolves ambiguity by evidence + research, fans out sub-agents. Also the `--yolo` flag on `ship` / `fix`. **Bundled.** |

### Self-contained by design

`ship` chains `simplify`, `verify`, and `code-review`. On Claude Code those exist as
built-ins — but on Codex, Grok, Hermes, or OpenClaw they don't. So ship-kit **ships its own
portable copies** of all three. `ship` prefers a richer native/built-in skill of the same
name when the host provides one (e.g. Claude Code's `code-review` with its cloud `ultra`
mode) and falls back to the bundled copy everywhere else. Result: the pipeline runs the same
on every harness.

## Install

Pick the line for your agent. See [docs/INSTALL.md](docs/INSTALL.md) for the full matrix,
project-scoped installs, and troubleshooting.

**Claude Code** (plugin marketplace):

```
/plugin marketplace add nsollazzo/ship-kit
/plugin install ship-kit
```

**Codex, Grok, OpenClaw, VS Code, or any Agent-Skills agent** — clone and run the installer:

```bash
git clone https://github.com/nsollazzo/ship-kit && cd ship-kit
bin/install.sh agents      # → ~/.agents/skills  (the widest-reach open-standard path)
# or: bin/install.sh all   # installs into every harness it detects under $HOME
```

Per-harness targets: `agents` (Codex / Grok community / OpenClaw / VS Code), `claude`,
`grok` (xAI Grok Build), `hermes`, `openclaw`, `copilot`. Use `--project` to drop the skills
into the current repo's `.agents/skills/`, or `--dest <dir>` for an arbitrary location.

**Nous Hermes** — install natively as a Tap (no clone needed):

```
hermes skills tap add nsollazzo/ship-kit
```

**xAI Grok** needs nothing extra: official **Grok Build** reads this repo's Claude plugin
(`marketplace.json` → `.agents`) with zero config, and the **community grok-cli** scans
`.agents/skills/` — so `bin/install.sh grok` or the Claude plugin path both work.

### Ask your agent to install it

Most of these agents have shell access, so you can just ask the agent to install ship-kit
for you. Paste one of these:

- **Any shell-capable agent (Codex, Grok, OpenClaw, …):**
  > Install the ship-kit skills for me: clone `https://github.com/nsollazzo/ship-kit` and run
  > `bin/install.sh` with the target that matches this agent (one of: agents, claude, grok,
  > hermes, openclaw, copilot). Then reload skills and confirm `ship` and `babysit` are listed.
- **Nous Hermes:**
  > Run `hermes skills tap add nsollazzo/ship-kit`, then list skills and confirm `ship` and `babysit` loaded.
- **Claude Code:** type `/plugin marketplace add nsollazzo/ship-kit`, then `/plugin install ship-kit`.

## Using it

Once installed, just say what you want — the skills auto-trigger by description on every
agent:

> *"fix this bug: …"* · *"triage this failure"* · *"ship it"* · *"babysit PR 412"* ·
> *"smart commit my changes"* · *"reflect on this session"*

They're also slash commands where the host exposes them: `/ship-kit:ship` on Claude Code,
`$ship` on Codex, `/ship` on Grok / Hermes / OpenClaw. `ship` takes flags — `--fast`,
`--merge`, `--no-verify`, `--yolo`; `fix` takes `--yolo` (plus the ship flags it passes
through). `--yolo` runs hands-off (no questions); it stops at green unless you also pass
`--merge`.

**Full usage guide** — the pipeline stage by stage, every flag, `babysit`, and worked
examples: **[docs/USAGE.md](docs/USAGE.md)**.

## Requirements

- The [`gh`](https://cli.github.com/) CLI, authenticated (`gh auth status`), for `babysit`
  and `ship`'s PR steps.
- A git repository with a GitHub remote.

## Notes

- **`babysit` never merges and never mutates external state to force a gate green.** It
  drives to approval; a human merges.
- **Project conventions override the recipe.** `ship` defers to a repo's own instruction
  file (`CLAUDE.md`, `AGENTS.md`, …) and its verify/test recipe — e.g. a project that forbids
  a tracked `CHANGELOG.md`, or runs tests in CI rather than locally.
- **One source of truth.** The canonical skills live in `.agents/skills/`. The Claude Code
  plugin reads them directly (the marketplace points its plugin `source` at `./.agents`).
  The only generated tree is `skills/` — a flat mirror for Hermes Taps, produced by
  `bin/build-adapters.sh` (run it after editing a skill; `--check` verifies it's in sync).

## License

MIT
