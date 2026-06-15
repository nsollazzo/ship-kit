# ship-kit

A Claude Code plugin that takes a finished change from working tree to a green,
mergeable pull request — and keeps the PR honest until a reviewer approves it.

## What's inside

| Command | What it does |
|---------|--------------|
| `/ship` | Orchestrates the full pipeline: **simplify → verify → code-review → smart-commit → branch hygiene → PR → babysit → reflect.** Stops at *approved + CI green + mergeable*; only merges with `--merge`. |
| `/babysit <PR#> [owner/repo]` | Drives one GitHub PR to a **fresh APPROVED + all CI green + `mergeable`** state. Each pass verifies every review finding against the code, fixes the valid ones, pushes back with evidence on the invalid, and replies on every thread. Never merges — a human does that. |
| `/smart-commit` | Clusters uncommitted changes into logical groups and commits each with a conventional-commit message. |
| `/reflect` | Captures session lessons (gotchas, patterns, integration quirks) into the knowledge base. Self-gating (early-exits when the work was routine) and never writes without your approval. Runs as `/ship`'s final step. |

`/ship` calls `simplify`, `verify`, `code-review`, and `loop` — these are built-in
Claude Code skills, present on any install. It calls `smart-commit`, `babysit`,
and `reflect`, all of which ship inside this plugin. So the bundle is
self-contained.

## Install

```
/plugin marketplace add nsollazzo/ship-kit      # or your fork's owner/repo
/plugin install ship-kit
```

Then `/ship`, `/babysit`, and `/smart-commit` are available in any session.

To try it locally before publishing, point the marketplace at this directory:

```
/plugin marketplace add /absolute/path/to/ship-kit
/plugin install ship-kit
```

## Requirements

- The [`gh`](https://cli.github.com/) CLI, authenticated (`gh auth status`), for
  `/babysit` and `/ship`'s PR steps.
- A git repository with a GitHub remote.

## Notes

- **`/babysit` never merges and never mutates external state to force a gate green.**
  It drives to approval; a human merges.
- **Project `CLAUDE.md` overrides the recipe.** `/ship` defers to a repo's own
  verify/test recipe and conventions (e.g. a project that forbids a tracked
  `CHANGELOG.md`, or runs tests in CI rather than locally).

## License

MIT
