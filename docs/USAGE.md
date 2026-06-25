# Using ship-kit

Once [installed](INSTALL.md), ship-kit's skills are available two ways on every harness:

- **Auto-trigger by description** — just say what you want in plain language: *"fix this
  bug: …"*, *"triage this failure"*, *"ship it"*, *"babysit PR 412"*, *"smart commit my
  changes"*, *"reflect on this session"*. The agent
  matches your request to the skill and runs it. This works everywhere and is the main way
  to use the kit.
- **Slash / explicit command** — where the host exposes one:

  | Harness | How you invoke a skill explicitly |
  |---------|-----------------------------------|
  | Claude Code | `/ship-kit:ship`, `/ship-kit:babysit`, … (plugin skills are namespaced) |
  | OpenAI Codex | `$ship`, `$babysit`, … (or implicit by description) |
  | xAI Grok | `/ship`, `/babysit`, … |
  | Nous Hermes | `/ship`, `/babysit`, … (each skill is auto-exposed as a slash command) |
  | OpenClaw / VS Code | `/ship`, `/babysit`, … |

## `fix` — reported bug → green, mergeable PR

`fix` is the inbound headliner. Point it at a *problem* — an error, a failing test, a
described misbehavior — and it diagnoses, implements, and ships the fix:

```
triage (diagnose) → branch → implement at the root cause → ship (→ green PR)
```

1. **triage** — fans parallel sub-agents across the issue (reproduce, recent changes,
   backward root-cause trace, blast-radius), adversarially verifies the leading cause, and
   proposes the fix. If it can't reach a root cause backed by evidence, `fix` **stops** rather
   than guessing.
2. **branch** — cuts a `fix/<slug>` branch from the diagnosis.
3. **implement** — applies the fix at the source (failing-test-first where there's a harness),
   not at the symptom.
4. **ship** — hands off to the `ship` pipeline below for the whole way to a green PR.

**Just say:** *"fix this bug: <description / error / failing test>"* — or `/ship-kit:fix`
(Claude) / `$fix` (Codex) / `/fix` (others).

### Flags

| Flag | Effect |
|------|--------|
| `--yolo` | Hands-off: never ask a question. Triage runs autonomously, the fix is implemented without a confirm pause, and `ship`'s checkpoint auto-confirms. Stops at green — merge still needs `--merge` |
| `--merge` / `--fast` / `--no-verify` | Passed through to `ship` (see its flags below) |

Example: *"fix the null-deref in the importer --yolo"* → triages with sub-agents, branches,
writes a failing test + the source fix, then runs the full ship pipeline to a green PR without
stopping to ask.

## `ship` — working tree → green, mergeable PR

`ship` is the outbound headliner. Point it at a finished change and it runs the whole pipeline:

```
simplify → verify → code-review → smart-commit → branch hygiene → PR → babysit → reflect
```

It stops at **approved + CI green + mergeable** and lets a human merge — unless you pass
`--merge`. There is exactly one pause: a checkpoint before it pushes / opens the PR.

**Just say:** *"ship it"* — or `/ship-kit:ship` (Claude) / `$ship` (Codex) / `/ship` (others).

### Flags

| Flag | Effect |
|------|--------|
| `--fast` | Skip simplify + code-review — for tiny changes |
| `--merge` | Squash-merge once green (also authorizes the push without re-asking) |
| `--no-verify` | Skip the runtime verify step — docs/config-only changes (the rebase check still runs) |
| `--yolo` | Hands-off: auto-confirm the checkpoint and resolve mid-pipeline ambiguity autonomously instead of pausing. Stops at green — merge still needs `--merge` |

ship-kit's bundled `code-review` has no effort/depth flag — it scales thoroughness by fanning
out across parallel sub-agents (review dimensions + adversarial verification), sized to the
change. (On Claude Code, ship prefers the richer **built-in** `code-review`, which *does* have
effort levels and a cloud `ultra` mode — see [INSTALL.md](INSTALL.md).)

Example: *"ship this with --fast --merge"* on a one-line typo fix → cleans, commits, opens
the PR, drives it to green, and squash-merges, without stopping to ask.

### What each stage does

1. **simplify** — quality cleanup (reuse / simplification / efficiency) over the change.
2. **verify** — runs your project's tests / app and confirms the change actually works.
3. **code-review** — finds correctness bugs + cleanups and applies the fixes (`--fix`).
4. **smart-commit** — clusters the changes into conventional commits.
5. **branch hygiene** — renames the branch to `<type>/<slug>` if needed.
6. **checkpoint** — the one pause: shows you the summary and asks before pushing.
7. **PR** — pushes and opens a PR with a written-up body.
8. **babysit** — drives the PR to green (see below).
9. **reflect** — captures any lessons from the session (asks before saving).

> On Claude Code, steps 1–3 use the richer **built-in** `simplify`/`verify`/`code-review`;
> on other agents they use ship-kit's bundled copies. Either way the pipeline is the same.

## `triage` — diagnose before you fix

`triage` is the diagnostic engine `fix` runs first — and it's useful on its own when you want
to *understand* a bug without changing anything yet. It fans parallel sub-agents across
different angles, **adversarially verifies** the leading root cause (an independent agent tries
to refute it), and reports:

```
symptom → root cause (with file:line / command-output evidence) → recommended fix → next step
```

It's **read-only** — it proposes, it never edits code. Its Iron Law: no proposed fix without a
verified root cause. When you're ready to apply the proposal, hand off to `fix`.

**Just say:** *"triage this"* / *"why is this failing?"* / *"what's the root cause?"* (or
`/ship-kit:triage`, `$triage`, `/triage`).

## `babysit` — drive a PR to a green approval

Give it a PR number and it loops: each pass reads new review feedback, **verifies every
finding against the actual code**, fixes the real ones (with a commit + reply), pushes back
with evidence on the false positives, replies on every thread, and re-checks CI — until the
PR is **freshly APPROVED + all CI green + mergeable**. It never merges; a human does that.

**Just say:** *"babysit PR 412"* (or `/ship-kit:babysit 412`, `$babysit 412`, `/babysit 412`).
Add the repo if it's not the current one: *"babysit PR 412 in nsollazzo/ship-kit"*.

**Looping until green:** one run = one check-react pass. To keep going automatically, use
your harness's recurring mechanism (Claude Code's `loop` skill, a Hermes cron/blueprint, or
just ask the agent to keep checking). With no loop primitive it iterates in-session.

Needs the [`gh`](https://cli.github.com/) CLI authenticated (`gh auth status`).

## `smart-commit` — clean, conventional commits

Clusters your uncommitted changes into logical groups and commits each with a conventional
message (`feat:`, `fix:`, `docs:`, …). Honors a `CHANGELOG.md` if one exists.

**Just say:** *"smart commit"* / *"commit my changes"*.

## `reflect` — capture what the session taught

Scans the session for non-obvious lessons (gotchas, integration quirks, new patterns) and
proposes saving them to your knowledge base (memory / instruction file / docs). It
self-gates (says "no new knowledge" on routine work) and **never writes without your `ok`**.

**Just say:** *"reflect"* / *"what did we learn"*. Runs automatically as `ship`'s last step.

## `yolo` — autonomous, hands-off mode

`yolo` is the standing "stop asking, just go" mode: it never asks clarifying questions,
resolves ambiguity by reading the codebase + researching the web, states each assumption in
one line, and fans out sub-agents for anything non-trivial. It keeps one safety floor —
pausing only before genuinely irreversible / outward-facing / money-spending actions.

You can run it as a mode (*"yolo"*, *"just do it"*, *"figure it out"*) **or** pass it as the
`--yolo` flag on `ship` / `fix` to make those run hands-off (the flag operates under these same
rules). On `ship`/`fix`, pushing and opening the PR *is* the explicit ask, so the safety floor
doesn't stop them there — only a `--merge` authorizes the irreversible merge.

## Tips

- **Project conventions win.** `ship` defers to your repo's instruction file (`CLAUDE.md`,
  `AGENTS.md`, …) and its own test/verify recipe — e.g. a repo that runs tests in CI rather
  than locally, or forbids a tracked `CHANGELOG.md`.
- **Tiny change?** `--fast` skips the cleanup + review stages.
- **Headless / CI / unattended?** Without `--merge` or `--yolo`, `ship` stops at the push
  checkpoint and reports "staged and waiting" rather than guessing — pass `--yolo` to authorize
  hands-off to a green PR (a human still merges), or `--merge` to authorize all the way through
  the squash-merge.
- **Nothing to do?** `ship` detects a clean tree with no open PR and says "nothing to ship".
