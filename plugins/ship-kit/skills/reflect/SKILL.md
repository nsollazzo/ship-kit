---
name: reflect
description: |
  Capture session knowledge (gotchas, patterns, integration quirks) into the project's knowledge base.
  Use when: session involved tricky bugs, new integrations, non-obvious patterns, or hard-won lessons.
  Also use when asked to "reflect", "capture lessons", "what did we learn", "session recap",
  or "save knowledge". Works after any coding session, not just commits.
---

# Reflect — Session Knowledge Capture

Scan the current session for valuable lessons and route them to the right knowledge target.

## Workflow

### Step 1: Gather Session Context

Read-only scan of what happened this session:

```bash
git diff main --stat
git log main..HEAD --oneline
git diff main
```

Also review conversation context: problems solved, errors hit, workarounds applied, patterns discovered.

### Step 2: Scan Existing Knowledge Base

Quick skim (not full read) to avoid duplicates:

- `~/.claude/projects/*/memory/MEMORY.md` — current gotchas
- Project `CLAUDE.md` — current rules
- `~/.claude/skills/` directory listing — skill coverage
- `docs/` directory listing — existing documentation

### Step 3: Identify Knowledge Gaps

Classify each insight into exactly one category:

| Category | Target | When |
|----------|--------|------|
| **Gotcha** | MEMORY.md | Non-obvious trap or workaround |
| **Rule** | CLAUDE.md | Project-wide always/never pattern |
| **Skill update** | `.claude/skills/<name>/` | Existing skill missing info |
| **New skill** | `/skill-creator` | New integration worth codifying |
| **Docs** | `docs/` | Missing guide or troubleshooting |

**Filters:**
- Skip routine changes (simple renames, formatting, obvious fixes)
- Skip duplicates of existing knowledge
- Max 7 suggestions
- Priority: gotchas > rules > skill updates > docs > new skills

### Step 4: Present Verdict

Concise table — scannable in 5 seconds. State your own verdict per item: what is worth saving (**save**) and what is not (**skip**, with the reason). Don't present a neutral menu — commit to a recommendation.

```markdown
## Session Reflection

| # | Category | Target | Verdict | Insight |
|---|----------|--------|---------|---------|
| 1 | Gotcha | MEMORY.md | save | Convex v.array() inside unions panics |
| 2 | Skill | /workos | save | Add headless login refresh pattern |
| 3 | Docs | docs/ | skip — already covered by deploy runbook | Coolify env steps |

**Why 1:** We hit a runtime panic when... (1 sentence)
**Why 2:** The headless flow required... (1 sentence)
```

If nothing worth capturing: **"No new knowledge. Existing docs cover this session."** — stop here.

### Step 5: User Approval

Do NOT use AskUserQuestion. End the turn with: **"Saving 1–2, skipping 3 — ok?"** and wait for the user's reply in chat:
- **ok / yes / 👍** → apply your verdicts as presented
- **ko / no** → apply nothing
- **a comment** (e.g. "also save 3", "drop 2", "reword 1") → adjust the verdicts accordingly, then apply

NEVER auto-apply without that reply.

### Step 6: Apply Approved Updates

For each approved suggestion:

| Category | Action |
|----------|--------|
| **Gotcha** | Append to MEMORY.md under appropriate section heading |
| **Rule** | Add to CLAUDE.md in the relevant section |
| **Skill update** | Edit the skill's SKILL.md or references/ |
| **New skill** | Print "Run `/skill-creator` to build X" — NEVER auto-create skills |
| **Docs** | Create or update file in `docs/` |

Keep edits minimal — add bullet points, don't reorganize existing content.

### Step 7: Commit Knowledge Changes (Optional)

Ask user whether to commit with: `docs: capture session lessons`

If user declines, leave changes staged but uncommitted.

## Rules

- NEVER auto-apply without user approval (Step 5) — but approval is a plain chat reply (ok/ko/comment), never an AskUserQuestion menu
- NEVER create new skills directly — route to `/skill-creator`
- NEVER modify source code — only knowledge files (MEMORY.md, CLAUDE.md, skills, docs)
- Max 7 suggestions per reflection
- Keep it FAST — this should take under 60 seconds
- Gotchas → MEMORY.md, permanent patterns → CLAUDE.md
- One sentence of "why" context per suggestion — no essays
