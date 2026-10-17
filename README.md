# agent-config

The team's shared setup for Claude Code and Codex. One source of standards
that both agents read, plus a template that makes every project easy for a
teammate (or an agent) to pick up.

This replaces copying the global `CLAUDE.md` from the shared drive by hand.
Updating your standards is now `git pull`.

## How it works

| File | Read by | Purpose |
|---|---|---|
| `AGENTS.md` | Claude and Codex | Team-wide standards: architecture, C#/.NET, logging, config, database, testing, security, GitLab branching |
| `claude/orchestration.md` | Claude only | Session-start project checks, planning rules, and delegation: Claude plans, Codex implements and reviews |
| `codex/config.toml` | Codex | Default model settings (seeded once, never overwritten) |
| `project-template/` | | Files every project repo should have |
| `scripts/` | | `install` and `init-project`, in PowerShell (Windows) and bash (WSL/macOS/Linux) |

**Why two files?** `AGENTS.md` holds the rules every agent must follow when
writing code. `orchestration.md` holds the interactive parts (asking the
developer questions, getting a plan approved), which only make sense for
Claude. Codex agents run unattended in the background and would stall
waiting for answers.

**Why Codex does the heavy lifting:** Claude usage is capped per developer;
Codex isn't. `orchestration.md` keeps Claude on high-judgment work (planning,
specs, tickets, verifying) and sends implementation, tests, debugging, and
review to Codex. It's written for the lowest team budget so the workflow is
the same for everyone.

## Setup (once per developer)

**Windows (PowerShell):**

```powershell
git clone <this repo's GitLab URL> $HOME\agent-config
powershell -ExecutionPolicy Bypass -File $HOME\agent-config\scripts\install.ps1
```

**WSL / macOS / Linux:**

```bash
git clone <this repo's GitLab URL> ~/agent-config
~/agent-config/scripts/install.sh
```

The install script:

1. Checks for `git`, `node`, `claude`, `codex`, and `glab`, and tells you how to install anything missing
2. Writes a managed block at the top of `~/.claude/CLAUDE.md` that imports `AGENTS.md` and `orchestration.md` from this repo. **Your old global `CLAUDE.md` is backed up** to `CLAUDE.md.bak-<timestamp>`; its content now lives in `AGENTS.md`.
3. Links `~/.codex/AGENTS.md` to this repo's `AGENTS.md`
4. Creates `~/.codex/config.toml` if you don't have one
5. Installs Matt Pocock's skills in both agents, plus the Codex plugin for Claude Code (skip with `-NoPlugins` / `--no-plugins`)

Then, in Claude Code, run `/codex:setup` to confirm Codex is logged in and
`/memory` to confirm both agent-config files are loaded.

**Updates:** `git pull` here. Both agents pick up changes in their next session.

> **Windows symlinks:** creating the Codex link needs Windows Developer Mode
> (Settings → System → For developers) or an admin shell. Without either, the
> script copies the file instead and tells you so. In that case, re-run the
> install script after each `git pull`, or turn on Developer Mode and re-run once.

**Personal preferences:** add them to `~/.claude/CLAUDE.md` below the
managed block, including your own `@` imports. Re-running the install script
only ever rewrites the lines between the `BEGIN`/`END agent-config` markers.

## Setup (once per project)

```powershell
powershell -ExecutionPolicy Bypass -File $HOME\agent-config\scripts\init-project.ps1 C:\path\to\project
```

(or `~/agent-config/scripts/init-project.sh path/to/project`)

It copies in any template files the project is missing and never overwrites
existing ones. **Projects set up under the old standards** have a `CLAUDE.md`
with real content: the script moves that content into `AGENTS.md` (which Codex
can read) and makes `CLAUDE.md` a one-line `@AGENTS.md` import.

Then:

1. Fill in the TODOs in `AGENTS.md`, or ask Claude to fill them in by inspecting the solution
2. Run `/setup-matt-pocock-skills` (choose GitLab, your triage labels, and `docs/` for docs)
3. Commit on a `chore/` branch and open an MR into `dev`

You can also skip the script: open Claude Code in a project with no
`AGENTS.md`, and it asks the new-project questions and generates the file.

The project's `.claude/settings.json` lists the plugins, so a teammate who
opens the repo in Claude Code is prompted to install anything missing.

## The workflow

**Why it's shaped this way:** agents are sharpest early in a session (the
"smart zone") and get gradually sloppier as context fills up, commonly from
around 125–150K tokens (the "dumb zone"). Instead of one long session that
plans, codes, and reviews, the work is split so every session starts fresh:
planning produces a spec and tickets in GitLab, each ticket fits in one fresh
session, and every Codex task starts with a clean context. When a session gets
long anyway, `/handoff` to a fresh one. See Matt's
[smart zone](https://www.aihero.dev/ai-coding-dictionary/smart-zone) entry.

**Step 1: plan, picking the starting point by size.** Plans live in GitLab
issues, not a local `TODO.md`, so the whole team can see them.

| Situation | Start with | What it does |
|---|---|---|
| New project, large epic, or lots of unknowns | `/wayfinder` | Maps the work as decision tickets in GitLab and resolves them one at a time, across as many sessions as needed. Produces specs and tickets from the map. |
| Well-scoped feature or fix | `/grill-with-docs` | Interviews you until every decision is made, updating `GLOSSARY.md` and ADRs, then `/to-spec` and `/to-tickets` |
| Small edit or quick fix | Just ask | No ceremony needed |

**Step 2: build, review, ship.**

| Step | Command | Runs on |
|---|---|---|
| Implement each ticket | `/codex:rescue --background implement #123 using the tdd skill` | Codex |
| Review | `/codex:review --base dev` (+ `/codex:adversarial-review --base dev` for risky changes) | Codex |
| Open the MR into `dev` | `glab mr create`, body in the `pr` skill's shape | Either |
| Hand work to a teammate | `/handoff` | Claude |
| Improve the setup | `/retro` | Claude |

Check background jobs with `/codex:status` and `/codex:result`. Use a separate
git worktree for each parallel Codex job.

## Changing the standards

Edit `AGENTS.md` through a merge request like any other code. Keep it to
rules that apply to every project: each line costs tokens in every session
of both agents. Project-specific rules go in the project's `AGENTS.md`;
situational how-tos belong in a skill.
