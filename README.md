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
| `claude/orchestration.md` | Claude only | Session-start project checks, planning rules, and delegation: Claude plans and verifies, a worker implements and reviews |
| `claude/delegation-codex.md` / `delegation-claude.md` | Claude only | Who the worker is. Each developer loads one (see below). |
| `codex/config.toml` | Codex | Default model settings (seeded once, never overwritten) |
| `project-template/` | | Files every project repo should have |
| `scripts/` | | `install` and `init-project`, in PowerShell (Windows) and bash (WSL/macOS/Linux) |

**Why two files?** `AGENTS.md` holds the rules every agent must follow when
writing code. `orchestration.md` holds the interactive parts (asking the
developer questions, getting a plan approved), which only make sense for
Claude. Codex agents run unattended in the background and would stall
waiting for answers.

**Who does the heavy lifting:** Claude usage is capped per developer.
`orchestration.md` keeps Claude on high-judgment work (planning, specs,
tickets, verifying) and sends implementation, tests, debugging, and review to
a **worker** that starts with a fresh context. Each developer chooses the worker:

| Mode | Worker | Good for |
|---|---|---|
| `codex` (default if Codex is installed) | Codex agents, effectively unlimited usage | Stretching a capped Claude budget furthest |
| `claude` | Claude subagents, on a smaller model where possible | Developers who don't want to use Codex, or have the Claude budget for it |

Either way the process and its outputs are identical: the same tickets,
commits, reviews, and MRs. Teammates can pick up each other's work without
caring which mode built it.

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

To choose a mode on first install, add `-Delegation codex` or
`-Delegation claude` (`--delegation codex|claude` in bash). Leave it off and
the script picks `codex` if Codex is installed, otherwise `claude`.

The install script:

1. Checks for `git`, `node`, `claude`, and `glab` (plus `codex`, which is optional), and tells you how to install anything missing
2. Sets your delegation mode
3. Writes a managed block at the top of `~/.claude/CLAUDE.md` that imports `AGENTS.md`, `orchestration.md`, and your delegation file from this repo. **Your old global `CLAUDE.md` is backed up** to `CLAUDE.md.bak-<timestamp>`; its content now lives in `AGENTS.md`.
4. Links `~/.codex/AGENTS.md` to this repo's `AGENTS.md` and creates `~/.codex/config.toml` if you don't have one (harmless if you never use Codex)
5. Installs Matt Pocock's skills in Claude Code, and if Codex is installed, in Codex too, plus the Codex plugin for Claude Code (skip with `-NoPlugins` / `--no-plugins`)

Then, in Claude Code, run `/memory` to confirm the three agent-config files
are loaded. In Codex mode, also run `/codex:setup` to confirm Codex is logged in.

### Switching modes

- **For good:** re-run the install script with the other mode, e.g.
  `install.ps1 -Delegation claude -NoPlugins`. It applies to new Claude
  sessions. Re-runs without the flag keep whatever you chose last.
- **For one task:** just say so in the session: "use Codex for this one",
  "use a Claude subagent for this", or run a `/codex:` command directly.
  Claude goes back to your default afterward.

Installing Codex doesn't commit you to Codex mode. With Codex installed, the
Codex plugin is available in either mode, so per-task switching works.

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

The project's `.claude/settings.json` enables Matt Pocock's skills, so a
teammate who opens the repo in Claude Code is prompted to install them. The
Codex plugin is left to each developer's install, since not everyone uses it.

## The workflow

**Why it's shaped this way:** agents are sharpest early in a session (the
"smart zone") and get gradually sloppier as context fills up, commonly from
around 125–150K tokens (the "dumb zone"). Instead of one long session that
plans, codes, and reviews, the work is split so every session starts fresh:
planning produces a spec and tickets in GitLab, each ticket fits in one fresh
session, and every worker task starts with a clean context. When a session gets
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

| Step | Codex mode | Claude mode |
|---|---|---|
| Implement each ticket | `/implement #123` (Claude routes the work to Codex), or directly: `/codex:rescue --background implement #123 using the tdd skill` | `/implement #123` (runs in a Claude subagent) |
| Final review of the branch | `/codex:review --base dev` (+ `/codex:adversarial-review --base dev` for risky changes) | `/code-review` against `dev` (+ ask for a design-challenge review for risky changes) |
| Open the MR into `dev` | `glab mr create`, body in the `pr` skill's shape | same |
| Hand work to a teammate | `/handoff` | same |
| Improve the setup | `/retro` | same |

In Codex mode, check background jobs with `/codex:status` and `/codex:result`.
In either mode, use a separate git worktree for each parallel worker.

## Changing the standards

Edit `AGENTS.md` through a merge request like any other code. Keep it to
rules that apply to every project: each line costs tokens in every session
of both agents. Project-specific rules go in the project's `AGENTS.md`;
situational how-tos belong in a skill.
