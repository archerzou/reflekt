# Building a Project with an AI Agent Team

A replicable method for building a real application with AI coding agents — the exact
approach used to build Reflekt. This is a "how to set it up and run it" guide, written so
you can lift the method onto a new project of your own.

The method rests on three ideas:

1. **Separate roles, not one assistant.** Design, implementation, and review are done by
   different agents with different permissions. No single agent does everything.
2. **Files are the memory, not the chat.** Every decision lands in a Markdown file (spec →
   plan → implementation → review → lessons). The context window is disposable; the files
   survive session resets, compaction, and machine switches.
3. **The system improves itself.** Lessons captured after each feature flow back into the
   agents' own instructions, so the setup gets sharper over time instead of staying static.

It works with any agentic coding tool (Claude Code, Codex CLI, Copilot) because it is built
on conventions and role separation, not tool-specific features.

---

## 1. Two Maturity Levels

The method scales. Reflekt actually grew through two generations, and you should too — start
simple, add ceremony only when a real failure justifies it.

| Level | Roles | Coordination | When to use |
|-------|-------|--------------|-------------|
| **Level 1 — Two agents** | Architect + Developer | You switch between two terminals and relay by hand | Learning the method; solo projects; any codebase you can hold in your head |
| **Level 2 — Agent team** | 8 agents behind a team lead | Hub-and-spoke messaging through a team lead; file-based handoffs | Production features; when you want the pipeline to run with less manual relaying |

Both levels use the **same file-based pipeline** (spec → plan → implement → review → lessons).
Level 2 just adds a PO (feature shaping), a dedicated reviewer, a critic (quality gate), a
learner (lessons consolidation), a solo agent (small fixes), and a team lead that routes all
messages. Read Level 1 first — Level 2 is the same spine with more vertebrae.

---

## 2. The Core Pipeline

```
Owner → PO (spec) → Architect (plan) → Developer (implement)
      → Architect (done check) + Reviewer (code review) → Done → Learner (lessons)
```

Every arrow is a file handoff. The human (owner) sits at every decision point and approves
each stage. Nothing merges without human sign-off.

### Stage-by-stage

| Stage | Who | Produces | The rule that makes it work |
|-------|-----|----------|------------------------------|
| **1. Shape the feature** | PO (or human) | `spec.md` — what to build, acceptance criteria | The spec describes *what and why*, never *how*. |
| **2. Ask questions in one batch** | Architect | (verbal / `questions.md`) | All clarifying questions at once — one round, not a drip of one-at-a-time questions. |
| **3. Plan** | Architect | `plan.md` — the contract | The plan is explicit: file paths, existing code to copy, which skill to use per step. The developer reads it literally. |
| **4. Review the plan** | Human | annotations on `plan.md` | This is the cheapest place to fix a design. Fixing a plan beats fixing code. |
| **5. Ask questions in one batch** | Developer | (verbal / `questions.md`) | Developer reads the *whole* plan before touching code, then asks everything at once. |
| **6. Implement step by step** | Developer | code + `implementation.md` | Re-read each step from the plan (not memory). Announce "Step N done." Stop and ask if a step is wrong — never deviate silently. |
| **7. Staged review** | Developer self-review → Architect done check → Reviewer code review | `review.md` | Cheap checks first, expensive reasoning last (see §6). |
| **8. Fix, iterate, merge** | Developer | updated code | Loop until approved. Capped fix cycles (see §5). |
| **9. Capture lessons** | Both → Learner | `lessons.md` → updated instructions | Lessons feed back into the agents' own files. |

### Artifacts per feature

One folder per feature holds the whole paper trail:

```
docs/specs/{slug}/
  definition/
    spec.md              # What to build (PO/human)
    help.tooltips.md     # Optional: UI tooltip text wired during implementation
  delivery/
    plan.md              # How to build it — the contract (Architect)
    questions.md         # Batched questions + answers (Architect/Developer)
    implementation.md    # What was built, decisions, deviations (Developer)
    review.md            # Findings, conformance checklist (Architect/Reviewer)
    lessons.md           # Discoveries to feed back into the system (both)
    summary.md           # Completion signal (team lead/reviewer)
    communication-log.md # Message/state log for cross-session resume (Level 2)
```

**The `{slug}` naming convention** identifies a unit of work:

- Internal feature: `F{N}-{Name}` — e.g. `F29-TimerPerPhase`
- Jira epic / issue: `{KEY}-{2-3-words}` — e.g. `RET-101-board-export`
- Ad-hoc change: `adhoc-{Name}` (no `definition/` folder — delivery only)
- Bug: `BUG-{N}-{name}` · Gap: `GAP-{N}-{name}`

The slug is assigned once at the start and passed to every downstream agent. Agents never
invent it — they use exactly what was handed to them.

---

## 3. The Four Information Layers

The single most important design choice: **behavior and knowledge live in different files, and
each agent loads only what it needs.** Spread everything across these layers.

| Layer | Location | How it loads | Holds |
|-------|----------|--------------|-------|
| **Project instructions** | `CLAUDE.md` (root + per-service) | Auto-loaded every session | Repo map, tech stack, core principles (names only), guardrails. The onboarding doc. Keep it lean. |
| **Rules** | `.claude/rules/*.md` | Auto-loaded every session | Universal behavioral constraints — things true for *every* agent in *every* session (guardrail enforcement, status-table format, how to navigate the KB). |
| **Conventions** | `.claude/conventions/*.md` + `docs/conventions/*.md` | Loaded via `@` import by the agents that need them | Pipeline artifact formats (how to write `implementation.md`, `review.md`), coordination protocol, and coding standards (C#, Vue, EF Core). |
| **Agent files** | `.claude/agents/*.md` | Loaded when you invoke that agent | What one agent does and, crucially, never does. **Behavior only — no domain knowledge inline.** |
| **Skills** | `.claude/skills/{name}/SKILL.md` | Invoked on demand during work | Reusable code recipes encoding established patterns. |

**Why the split matters (the core trade-off):**

- Put everything in `.claude/rules/` (auto-load) and it is zero-config — but *all* rules load
  into *every* session, so the architect carries coding standards it never uses and the
  developer carries plan-format rules it never uses. Tokens wasted on every message.
- Put knowledge in `@`-imported convention files and each agent cherry-picks exactly what it
  needs. More precise, fewer tokens — at the cost of wiring up the imports.

Reflekt uses auto-loaded rules for the genuinely universal constraints and `@` imports for
everything role-specific. **Decision rule:** new instruction → put it in the *narrowest* scope
that covers it. Universal → a rule. One agent only → that agent's file. A code pattern → a skill.
A coding standard → a convention file.

**Where does X go?**

- Universal rule (all agents, all sessions) → `.claude/rules/{name}.md`
- Pipeline coordination (handoffs, routing) → `.claude/conventions/pipeline-protocol.md`
- Artifact format (how to write a given file) → `.claude/conventions/{name}-format.md`
- One agent's behavior → `.claude/agents/{agent}.md`
- Reusable code pattern → `.claude/skills/{name}/SKILL.md`
- Coding standard (naming, structure, stack) → `docs/conventions/`

---

## 4. The Agents

### Level 1 — the two that matter most

**Architect** — designs, never writes code.
- Runs on the strongest reasoning model (Opus-class), because design is where reasoning pays off.
- Imports only what it needs: architecture rules, business context, the workflow contract.
- Discusses the feature, asks every clarifying question in one batch, writes the plan, reviews
  the developer's output via a two-step gate. Reads skill *names* only (to reference in plans),
  not full skill bodies.

**Developer** — implements from plans, never designs.
- Runs on a planning-capable-but-cheaper configuration (`opusplan`: Opus for planning, Sonnet
  for routine implementation, switched automatically).
- Imports *all* convention files — cost matters less here than output quality.
- Reads the plan fully, asks all questions in one batch, implements step by step with explicit
  tracking, writes `implementation.md` and `lessons.md`.

### Level 2 — the full team

| Agent | Model class | Scope |
|-------|-------------|-------|
| **team-lead** | Opus | Orchestrates the pipeline, routes **all** messages (hub-and-spoke), manages commits |
| **po** | Opus | Shapes features from an idea, writes specs, answers product questions. *Cannot read code.* |
| **architect** | Opus | Plans, Step-1 done checks, answers developer questions. *Cannot write source code.* |
| **critic** | Opus | Quality gate — cross-checks specs against the product doc and plans against specs |
| **developer** | opusplan | Implements plan steps, writes `implementation.md` |
| **reviewer** | Sonnet | Step-2 code review with severity ratings. *Cannot implement.* |
| **learner** | Opus | Consolidates lessons, promotes proven patterns into the system files |
| **solo** | opusplan | Small scoped changes (1–3 files) that skip the full pipeline |

### What makes the agent files work

- **Behavior only.** An agent file says *how the agent acts and what it must never do* — not what
  the system looks like. Domain knowledge lives in conventions and architecture docs.
- **Sharp "Never Do" sections.** The highest-impact failure mode is an agent stepping outside its
  lane (architect writing code, PO reading code). Every agent file spells out its boundaries
  explicitly — even at the cost of some duplication across files. A missed guardrail is more
  expensive than a repeated one.
- **Front-load questions.** Every agent asks all its clarifying questions in one batch before
  starting real work. No mid-task surprises.
- **End with a ready signal.** "Architect ready." / "Developer ready." — suppresses wasted
  summary tokens and confirms the role loaded.

### Model economics

Use the expensive, high-reasoning model only where judgment lives (architect, planning,
done-checks). Use the cheaper model for mechanical work (implementation, checklist-style code
review). This is deliberate: it keeps you inside subscription limits on a real project. On
Reflekt, delegating mechanical codebase discovery to cheap "Explore" sub-agents kept Opus
reserved for decisions.

---

## 5. Communication Model (Level 2)

All agent messages route through the **team lead** — agents never message each other directly.

```
To team-lead: "For {recipient}: {message}"
```

The team lead triages every message before forwarding and decides:

1. **Routine handoff** ("ready for review") → forward it.
2. **Message that reverses a user decision, changes scope, or drops a plan step** → stop, ask
   the human first, then forward the answer.
3. **Question that needs human input** → relay to the human, wait, forward the answer.

**Why a single hub?** Auditability, and a guarantee that scope changes can't sneak past the
human. The single point of failure is an accepted trade-off for that guarantee.

**Cycle caps** stop infinite loops:

| Loop | Max | Then |
|------|-----|------|
| Reviewer ↔ Developer fix cycle | 3 | Escalate to architect |
| Developer questions (same area) | 3 | Escalate to human |
| Architect escalation | 1 | Escalate to human |

After escalation to the human, agents **stop and wait**.

---

## 6. The Staged Review (the cost trick)

Reviewing is where tokens get burned, so review runs cheapest-first:

1. **Developer self-review** — re-read the plan, verify each step shipped. Catches mechanical
   issues (missed files, wrong names, build failures, skipped steps). A Sonnet-class model
   handles this checklist work well.
2. **Architect done check — no code reading.** Cross-reference every plan step against
   `implementation.md`. If a step is missing, bounce it back to the developer *without reading a
   line of code*. Each step gets a disposition: Implemented / Deviated (with reason) /
   Missing / Superseded / N/A.
3. **Reviewer code review — only if the done check passes.** Re-read the plan, then verify each
   instruction has correct corresponding code. Severity-rated findings.

The point: don't spend expensive reasoning tokens pointing out a missing file. Let the cheap
checks catch the trivial stuff; reserve architectural judgment for last.

A nice touch used by the critic and reviewer: **pre-commitment prediction** — before reading the
code, predict the 2–3 most likely gaps, then check specifically for those. It counters
confirmation bias.

---

## 7. Skills — Encoding Patterns Once

A **skill** is a reusable recipe for a recurring pattern, so agents produce consistent code
without rediscovering conventions each time. Reflekt has ~37.

Structure:

```
.claude/skills/{skill-name}/
  SKILL.md              # Entry point with YAML frontmatter
  workflows/            # Optional multi-step sub-files, loaded on demand
    EndpointFastEndpoints.md
    Validator.md
  references/           # Optional templates
```

The frontmatter drives discovery and invocation:

```markdown
---
name: create-feature
description: Creates a complete vertical slice — endpoint, command/query, handler,
  validator, mappings, DI. Check the service CLAUDE.md for which framework to use.
---
```

- The `name` becomes a slash command (`/create-feature`).
- The `description` tells the agent *when* to reach for it — the tool reads all descriptions at
  startup and matches them to the task. This collection of descriptions *is* the skill index;
  a separate index file would just drift.
- Good skills include **Required Reading** (read these first), **Anti-patterns** (what people get
  wrong), numbered **Steps**, and a **verify** step (e.g. `dotnet build`).

**Skill authority:** skills are the authoritative source for patterns. If a skill exists, follow
it. If it references something the codebase lacks, build that. If no skill matches, the architect
may inline the pattern and log the gap in `lessons.md` — which is how new skills get born.

Plans map **each step to a skill** (or justify inline detail). That is what keeps generated code
consistent across dozens of features.

---

## 8. The Learning Loop (self-improvement)

This is what separates a one-off setup from a system that compounds.

```
feature work → lessons.md → learner reads all lessons.md across features
             → classifies each item, tracks recurrence
             → promotes proven patterns into: CLAUDE.md / a rule / a convention / an agent file / a skill
             → (human approves each promotion)
```

After every feature, both agents jot down what they learned — an undocumented convention, a skill
gap, an ambiguous plan pattern. Periodically the **learner** agent consolidates all `lessons.md`
files, counts how often each issue recurs, and proposes where each should be promoted. Changes
apply only after human approval. Over 32+ features this is what turned Reflekt's setup from a
rough two-agent flow into a refined pipeline.

A companion pattern worth copying: a **known-deviations table** that records recurring mistakes
with the wrong pattern, the correct pattern, and a frequency count.

**The tension to watch:** promotion is additive — the system only ever grows. Add a counter-force.
Reflekt's own evaluation recommends a **context budget per agent** (e.g. solo < 800 lines,
developer < 1200, architect < 1500): when the learner promotes a lesson that busts the budget, it
must also identify a line to cut or compress. Build the "shrink" pressure in from the start.

---

## 9. Session & Cost Discipline

Practical habits that keep a real project affordable and resumable:

- **Plans are the continuity layer, not the chat.** After `/compact` or `/clear`, point the agent
  back at the plan: "Read `plan.md` and continue from step 3." Files survive; context windows don't.
- **One session per feature**, named after the git branch (`/rename`). `/clear` between features to
  stop context bloat.
- **Minimal root `CLAUDE.md`** (target: well under ~100 lines) + scoped convention files — saves
  tokens on *every* message.
- **A `.claudeignore`** so the agent never reads `bin/`, `obj/`, generated migrations, lock files.
- **Expensive model only where it counts** — Opus for architecture, Sonnet/`opusplan` for
  implementation and checklist review.
- **Specific prompts** — vague requests trigger expensive exploration.
- **Stop early** (`Escape`) the moment an agent heads the wrong way — don't let it burn tokens.

---

## 10. How to Replicate This on a New Project

A checklist to stand the method up from scratch.

### Phase 1 — Foundation (before the first feature)

1. **Write a lean root `CLAUDE.md`:** 2–3 line project description, repo tree, core principles
   (names only), the hard guardrails ("DO NOT…"), and build/migration commands. Add per-service
   `CLAUDE.md` files if you have multiple services (they auto-load hierarchically).
2. **Write an architecture reference** (`docs/architecture/`) the agents can consult while
   planning — the as-built shape, plus a one-page index that imports it.
3. **Write convention files** for your stack (`docs/conventions/`): coding standards, testing
   approach, project rules. These are the detailed rules too large for `CLAUDE.md`.
4. **Author the agent files** (`.claude/agents/`): at minimum Architect and Developer. Behavior
   only. Give each a crisp "What You Never Do" section and a ready signal. Set the model per role.
5. **Write the workflow contract** (`.claude/conventions/pipeline-protocol.md` + artifact-format
   files): the plan format, implementation format, review format, lessons format.
6. **Add rules** (`.claude/rules/`) for the few genuinely universal constraints (guardrail
   enforcement, any output-format rules). Keep these small — they load every session.
7. **Seed a handful of skills** for your most repeated patterns (e.g. "create a feature slice",
   "create an aggregate"). Don't over-build upfront — let skills grow from real lessons.
8. **Set up `.claude/settings.local.json`** permissions (allow standard tools, deny destructive
   commands like force-push and recursive delete). Git-ignore the local settings file, not the
   whole `.claude/` folder — skills and shared setup should be committed.

### Phase 2 — Run a feature

9. Write (or have the PO write) `spec.md` under `docs/specs/{slug}/definition/`.
10. Load the Architect, describe the feature, answer its one batch of questions, get `plan.md`.
11. Review and annotate the plan until you approve it. **Spend your effort here.**
12. Load the Developer, point it at the plan, answer its one batch of questions, let it implement
    step by step and write `implementation.md`.
13. Run the staged review: developer self-review → architect done check → reviewer code review.
14. Fix, iterate, approve, merge. Have both agents write `lessons.md`.

### Phase 3 — Improve

15. After every few features, run the learner (or ask the architect) to process all `lessons.md`
    files and propose promotions into `CLAUDE.md`, conventions, agent files, or new skills.
    Approve each change. This is the flywheel.

### Start small

Begin at **Level 1 (two agents, manual relay)**. Add the PO, critic, reviewer, learner, and team
lead only when manual relaying becomes the bottleneck. Every piece of ceremony should earn its
place by solving a failure you actually hit — which is exactly how Reflekt's setup evolved.

---

## 11. Design Decisions Worth Copying

Intentional trade-offs from Reflekt's setup, each flagged by its own evaluation as a deliberate
choice rather than an oversight:

| Decision | Why |
|----------|-----|
| Two-phase agent invocation (analyze → checkpoint → execute) | Turns a platform limit (agents can't pause) into a quality gate. The human triages at the checkpoint. |
| Team lead as the sole message hub | Auditability and a guarantee that scope changes can't bypass the human. |
| Agent boundary rules repeated per agent | Boundary violations are the worst failure mode. Duplication is cheaper than a missed guardrail. |
| Serial pipeline, no parallelism | At 3–10 steps per feature, coordination overhead would exceed the time saved. |
| Rules auto-load for all sessions | Missing a guardrail mid-implementation costs more than the ~150 lines of context. |
| No skill index file | The collection of skill descriptions *is* the index; a separate file duplicates and drifts. |
| Files over chat for memory | Plans and records survive resets, compaction, and machine switches; the context window does not. |

---

## 12. Where to Look in This Repo

To study the method in the actual Reflekt tree:

| Path | What it shows |
|------|---------------|
| `ai-coding/ai-development-flow.md` | The original two-agent methodology, tool-agnostic |
| `ai-coding/claude-code-setup.md` | The full Level-1 setup: file structure, model choices, session discipline |
| `ai-coding/agents/`, `ai-coding/plans/` | First-generation agent files and per-feature records |
| `.claude/README.md` | The Level-2 eight-agent system overview and "where does this go" map |
| `.claude/agents/` | The current agent role files (architect, developer, reviewer, PO, critic, learner, solo, team-lead) |
| `.claude/conventions/pipeline-protocol.md` | The full pipeline flow, checkpoints, and message handoffs |
| `.claude/rules/` | The auto-loaded universal rules |
| `.claude/skills/` | ~37 skills — the pattern library |
| `docs/specs/{slug}/` | Current-generation per-feature folders (spec → plan → implementation → review → lessons → summary) |
| `docs/agentic-setup-evaluation.md` | A full critique of the setup — strengths, weaknesses, and recommended fixes |

> **A note on honesty in the records:** Reflekt deliberately keeps every generation of its setup,
> including the rough early versions and an evaluation that lists the setup's own broken references
> and weaknesses. When you build your own, keep the same honesty — the records exist to show how
> the system actually evolved, warts included, not to present a polished fiction.
