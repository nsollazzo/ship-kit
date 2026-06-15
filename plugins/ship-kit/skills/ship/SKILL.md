---
name: ship
description: Take a finished change from working tree to a green, mergeable PR by chaining simplify → verify → code-review → smart-commit → branch hygiene → PR → babysit. Use when the user says "ship", "ship it", "ship this", or wants the full clean→verify→review→commit→PR→green pipeline in one command. Default stops at approved + CI green + mergeable; does NOT merge unless --merge.
argument-hint: "[--fast] [--merge] [--effort low|medium|high] [--no-verify]"
---

# Ship — working tree to green PR, one command

Orchestrate the existing skills in order. **Invoke each stage via the Skill tool — never re-implement a stage's logic inline.** This skill only owns sequencing, gates, state, and the final report.

## Flags (parse from $ARGUMENTS)

| Flag | Effect |
|------|--------|
| `--fast` | Skip Stage 1 (simplify) and Stage 3 (code-review) — for tiny changes |
| `--merge` | Squash-merge once green (default: stop at green, human merges) |
| `--effort low\|medium\|high` | Pass through to code-review (default: medium) |
| `--no-verify` | Skip Stage 2b (runtime verify) — docs/config-only changes. The Stage 2a rebase check still runs |

## Cross-cutting rules

- **Fail loud, never skip silently.** A stage that fails HALTS the pipeline with the evidence. A stage skipped by flag must be named as "skipped (--flag)" in the final summary. Never report "shipped" if anything was silently skipped.
- **Project CLAUDE.md overrides this recipe.** Examples: a project that forbids a tracked CHANGELOG.md (skip smart-commit's changelog step there); a project whose tests run in a specific environment (CI, a container, a remote host) rather than locally; a project-specific verify/test recipe always beats the generic one.
- **State file** `.claude/ship-state.json` (repo-local, like /release's): write `{branch, head_sha, flags, completed_stages: []}` after each stage; on invocation, if it exists and `branch` matches the current branch, offer to resume from the next stage; delete it on success.

## Stage 0 — Preflight

1. Parse flags. Read state file → offer resume if it matches the current branch.
2. `git status` + `git log @{u}.. 2>/dev/null` + `gh pr view --json url,state 2>/dev/null`. If the tree is clean, nothing is unpushed, AND no open PR exists for this branch → say "nothing to ship" and stop.
3. **PR already open for this branch:** an open PR does NOT skip the quality stages — "pushed" is not "polished", and a local review pass is cheaper than a remote review round-trip (push + CI + re-review). Adjust as follows:
   - **Already APPROVED + CI green + mergeable** → don't touch it: pushing cosmetic fixes burns the green (babysit's own guardrail). Skip straight to Stage 9; mark stages 1–8 "N/A (PR already green)".
   - **Otherwise** → run stages 1–4 against the **PR's full diff vs base** (`git diff origin/<base>...HEAD`), not just the working tree. If they produce fixes, commit (Stage 4) and continue; if they produce nothing, say so and continue.
   - **Stage 5 is N/A**: never rename a branch with an open PR — deleting/repushing the remote ref closes the PR.
   - **Rebase (Stage 2a) becomes report-only**: report how far behind base the branch is, but don't rebase — once a PR is under review, babysit owns the decision of when an update-with-base is worth a re-review cycle.
   - **Stage 6/7**: the checkpoint gates pushing new fix commits to the existing PR (instead of "open PR?"); `--merge` authorizes it as usual. Stage 7 is just `git push` — no PR creation.
   - The final summary must still list every stage as run / produced-nothing / N-A with the reason — never silently omit them.
4. **Branch safety:** if on `main`/`master` with uncommitted work, create a working branch NOW (`git checkout -b wip/ship-<short-desc>`) before any stage mutates files. The final name is fixed in Stage 5 — don't bikeshed it here.
5. **Base branch:** in a Superconductor worktree, read it from `sc worktree status --json` (`target_branch`); otherwise use the repo default. Record it for Stage 7. (The fast-path needs this too — resolve it before the behind-base check.)

## Stage 1 — Simplify (skip if --fast)

Invoke the `simplify` skill. It applies quality cleanups to the working tree.

## Stage 2 — Verify (skip if --no-verify)

**2a. Rebase check (runs even with --no-verify):** verification against a stale base is worthless, so first check whether the branch should rebase onto the Stage 0 base branch:

```bash
git fetch origin <base>
git rev-list --count HEAD..origin/<base>            # commits we're behind
git diff --name-only HEAD...origin/<base>           # files base changed since we diverged
```

- Behind 0 commits → no rebase, continue.
- Behind, and base touched **any file this branch also touches** (compare against `git diff --name-only <merge-base> HEAD` + working-tree changes) → **rebase now** (`git stash` if dirty → `git rebase origin/<base>` → `git stash pop`). Overlap means the verify result would be a lie without it.
- Behind on disjoint files only → rebase anyway if it's cheap and clean (default), but a conflict here is not worth fighting pre-PR — abort the rebase and continue, noting "N commits behind base, disjoint, rebase deferred" in the Stage 6 summary.
- **Rebase conflict on overlapping files → STOP** (fail loud): abort the rebase, report the conflicting files, and ask the user how to resolve. Never auto-resolve conflicts in shipped code.

**2b. Verify:** invoke the `verify` skill: run the app/tests and observe the change actually working (post-rebase, if one happened).
**Gate:** if verification fails → STOP. Report exactly what failed and why the pipeline halted. Do not continue to review or commit broken work.

## Stage 3 — Code review (skip if --fast)

Invoke the `code-review` skill with `--fix` at the requested effort (default medium).
If it applied fixes AND Stage 2 ran: re-run the cheap verification (tests, not the full app walk) so review fixes are never committed unverified. Same gate as Stage 2.

## Stage 4 — Commit

Invoke the `smart-commit` skill to cluster and commit with conventional messages.
Honor project CLAUDE.md: where a tracked CHANGELOG is forbidden, tell smart-commit to skip its changelog step.

## Stage 5 — Branch naming

The branch must match `<type>/<kebab-slug>` where `<type>` ∈ {feat, fix, docs, chore, refactor, test, perf} — derive it from the dominant conventional-commit type of the commits being shipped; slug = short kebab-case summary of the change.

- Non-conforming (wip/ placeholder, personal prefix, etc.) → `git branch -m <type>/<slug>` BEFORE pushing.
- Already pushed under the old name → push the new name, then after the PR is open delete the old remote ref (`git push origin :<old-name>`).
- Already conforming → leave it alone.

## Stage 6 — CHECKPOINT (the one pause)

Present a compact summary: stages run (and skipped, with flags), verification evidence, review findings fixed, commit list, final branch name, drafted PR title + body.

Ask once (AskUserQuestion): **proceed to push + open PR?** This is the only outward-facing gate. Authorization rules:

- `--merge` on the invocation **is** standing authorization for all outward-facing steps (push, PR, merge) — do not re-ask at the checkpoint. The user opted into hands-off end-to-end by passing it.
- With a PR already open: the checkpoint gates pushing new fix commits to it (a push re-triggers CI + QA review). If the quality stages produced nothing, there's nothing to gate — record the checkpoint as N/A.
- Without `--merge` and with new work to push: the checkpoint question is mandatory. If running non-interactively (under /loop, headless), stop here and report "staged and waiting" rather than guessing.

## Stage 7 — Push + PR

1. `git push -u origin <branch>`.
2. `gh pr create` against the Stage 0 base branch. Body: what changed, why, how it was verified (cite the Stage 2 evidence). PR title must be conventional-format (some repos gate on it with a `pr-title` check). End the body with the standard Claude Code attribution footer.

## Stage 8 — Babysit to green

Run babysit **under the loop skill** so it self-paces until the goal: invoke the `loop` skill with args `/babysit <PR#> [owner/repo]` (the Stage 6 checkpoint already authorized hands-off continuation — don't ask again). Babysit defines the goal (fresh APPROVED + all CI green + mergeable) and ends the loop itself when it's met; each pass verifies every review finding before fixing, pushes back with evidence on false positives, and replies on every thread.

If the user wants a single status pass instead of the full loop, invoke `babysit` directly once.

## Stage 9 — End state

- **Default:** report "PR #N is green and mergeable: <url>" and STOP. A human merges.
- **--merge:** `gh pr merge <PR#> --squash --delete-branch` once green, then report the merge.
- Delete `.claude/ship-state.json`.
- Final summary must list every stage as run / skipped (--flag) / halted — no silent gaps.
- If the session surfaced gotchas or tricky bugs, suggest `/reflect`.
