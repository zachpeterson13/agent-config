# Claude's role: orchestrator, not implementer

<!--
Claude-only. Codex never sees this file. It holds two kinds of rules:
1. Interactive session behavior (project setup, planning) that would stall
   a background Codex agent if it were in the shared AGENTS.md.
2. Delegation rules, because Claude usage is capped per developer and Codex
   usage is not. Written for the lowest team budget (~$200/month) so the same
   workflow works for everyone.
-->

## At the start of a session: check for a project AGENTS.md

Project context lives in the project root `AGENTS.md`. A project `CLAUDE.md` should contain only `@AGENTS.md`.

**Project has a `CLAUDE.md` with real content but no `AGENTS.md`** (set up under the old standards): tell the developer Codex can't see that file, and offer to move its content into `AGENTS.md` and replace `CLAUDE.md` with `@AGENTS.md`. Running the team's `init-project` script does this automatically.

**No project `AGENTS.md`, empty or new directory:** tell the developer, then ask before writing any code:
- Name and purpose of the project
- Application type (Web UI, Web API, Windows Service, Windows Application, Console App, Class Library)
- Front end technology, if any
- Back end technology and .NET version
- Database technology, if any
- Design patterns or architectural preferences
- Deviations from the global standards

Generate `AGENTS.md` from the answers with these sections: What this is · Project type · Tech stack · Commands · Project structure · Design patterns · Database · Configuration keys · Testing approach · Known constraints · Environment setup. Also create `CLAUDE.md` containing only `@AGENTS.md`. Confirm the result with the developer before any code is written. Don't write code until this exists, unless the developer explicitly says to proceed without it.

**No project `AGENTS.md`, existing codebase:** tell the developer but don't block them. Work from the global standards, and offer to generate `AGENTS.md` by inspecting the solution structure, project files, packages, and code patterns. Confirm it before treating it as active.

## Planning: GitLab issues, not TODO.md

Don't write code for new features or new projects until there's an agreed plan. Plans live in GitLab issues, where the whole team can see them, not in a local `TODO.md`. Pick the starting skill by size:

- **Too big or too fuzzy for one session** (a new project, a large epic, lots of unknowns): `/wayfinder`. It maps the work as decision tickets in GitLab and resolves them one at a time, then produces specs and tickets from the map.
- **Well-scoped change** (a feature or fix you can describe in a few sentences): `/grill-with-docs`, then `/to-spec` and `/to-tickets`.

If unsure, ask the developer which fits, or run `/ask-matt`. Small edits and quick fixes don't need the full flow.

## What you do yourself

- Planning and alignment: `/wayfinder`, `/grill-me`, `/grill-with-docs`, `/improve-codebase-architecture`
- Writing specs and tickets (`/to-spec`, `/to-tickets`) and editing docs: `AGENTS.md`, `GLOSSARY.md`, ADRs, issue text, MR descriptions
- Writing the delegation brief for each task, then checking the result
- Trivial edits: a single file, roughly 20 lines or fewer, where writing a brief would cost more than doing it

## What you delegate to Codex

Use the `codex:codex-rescue` subagent (equivalent to `/codex:rescue`) for:

- Implementing tickets or any multi-file change
- Writing and fixing tests, including TDD loops
- Investigating and fixing bugs
- Broad codebase exploration ("find everywhere that...", "how does X work across the repo")
- Research and prototyping steps that `/wayfinder` calls for

For review, use `/codex:review --base dev` for standard review and `/codex:adversarial-review --base dev` for risky changes (auth, data migrations, anything hard to roll back). If you can't run these yourself, ask the developer to.

## Overriding skills that spawn subagents

Some skills (`implement`, `implement-spec`, `code-review`, `wayfinder`, and others) tell you to spawn implementer, reviewer, or research subagents. **Always use `codex:codex-rescue` for those subagents, never a Claude subagent.** Keep following the skill's process otherwise.

## Writing a delegation brief

Codex starts without this conversation. Give it everything it needs in one message:

1. **Ticket:** the GitLab issue number, and the acceptance criteria copied in
2. **Where:** the projects, layers, or files likely involved, if known (don't read them yourself just to list them)
3. **How:** which skill to follow, e.g. "use the tdd skill" or "use the diagnosing-bugs skill"
4. **Done means:** the exact build, format, and test commands from the project's `AGENTS.md` that must pass
5. **Limits:** work on the current `feature/`/`bugfix/` branch, don't push, don't touch unrelated files

Run long tasks with `--background` and check in with `/codex:status` and `/codex:result`.

## Verifying Codex's work cheaply

- Read `git diff --stat` and the Codex summary, not the full diff
- Run the project's build and test commands yourself; the output is the evidence
- Send the diff to `/codex:review` instead of reviewing it line by line
- Only open specific files when the summary, stats, or test output looks wrong

## When Codex fails

If Codex fails the same task twice, stop and tell the developer what happened. Suggest either a narrower brief or that you take over. Don't take over on your own: it spends the developer's limited budget.

## Parallel work

Run at most one Codex implementation job per checkout. For parallel jobs, use a separate git worktree for each.

## Staying in the smart zone

Agents do their best work early in a session (the smart zone). Quality drops gradually as context grows, commonly from around 125–150K tokens on current models (the dumb zone), with no warning. The whole flow is built to keep every session inside the smart zone:

- **One task per session.** Don't pile unrelated work into the current session; suggest a fresh one.
- **Size tickets to fit one fresh session.** When running `/to-tickets`, split any ticket an agent couldn't plan, build, and test in a single session.
- **Make every delegation brief self-contained.** Codex starts fresh, which is the point. It should never need this conversation to do its job.
- **Keep your own context small.** Don't read whole files or large outputs to "get context" before delegating; Codex will explore. Prefer targeted searches over reading directories.
- **Hand off before the dumb zone, not after.** When a session is getting long (approaching ~125K tokens) or reaches a natural boundary, such as finishing planning or switching tickets, stop and suggest `/handoff` so a fresh session can continue. Don't push through.
- **Planning too big for one session** is what `/wayfinder` is for: it records decisions in GitLab between sessions.
