# agent-config

My personal setup for Claude Code: one set of standards, plus a template that
makes every repo easy for an agent to pick up. Updating standards is `git pull`.

## The idea: I drive

The agent files hold **standards and rules**, not process. I choose the step
and the skill; the agent does the task it's given.

`AGENTS.md` is the source of truth. Claude Code reads it through a one-line
`CLAUDE.md` import.

## What's here

| Path | Purpose |
|---|---|
| `AGENTS.md` | Rules for **every** repo: principles, testing, security, GitHub branching, agent working rules. Loaded every session. |
| `standards/` | Stack standards (`dotnet.md`). Copied into each repo as `docs/standards/`, read **only when relevant** via a pointer in the repo's `AGENTS.md`. |
| `project-template/` | What `init-project` adds to a repo: `AGENTS.md`, one-line `CLAUDE.md` import, `.claude/settings.json` |
| `scripts/` | `install` (once per machine) and `init-project` (once per repo), PowerShell and bash |

## Setup (once per machine)

```powershell
git clone <this repo's GitHub URL> $HOME\agent-config
powershell -ExecutionPolicy Bypass -File $HOME\agent-config\scripts\install.ps1
```

```bash
git clone <this repo's GitHub URL> ~/agent-config
~/agent-config/scripts/install.sh
```

The script:

1. Checks for `git`, `node`, `claude`, `gh`
2. Writes a managed block at the top of `~/.claude/CLAUDE.md` importing this repo's `AGENTS.md`. Old global `CLAUDE.md` is backed up to `CLAUDE.md.bak-<timestamp>`.
3. Installs Matt Pocock's skills (skip with `-NoPlugins` / `--no-plugins`)

Run `/memory` in a new Claude Code session to confirm `AGENTS.md` loaded.
Personal additions go in `~/.claude/CLAUDE.md` below the managed block.

## Setup (once per repo)

From the repo root, re-runnable:

1. Run `init-project` (no arguments). Adds what's missing, never overwrites: `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`, `docs/standards/`.
2. Run `/setup-matt-pocock-skills` (issue tracker: GitHub). If it writes its `## Agent skills` block into `CLAUDE.md`, re-run `init-project` to move it to `AGENTS.md`.
3. Fill in the TODOs in `AGENTS.md`.
4. Commit on a `chore/` branch, open a PR into `main`.

Existing .NET repos: if `AGENTS.md` lacks a `docs/standards/` pointer, the script prints the section to add.

## Workflow

1. **Plan, sized to the work.** Big/unknown: `/wayfinder`. Well-scoped: `/grill-with-docs` → `/to-spec` → `/to-tickets`. Small: just do it on a branch.
2. **Build.** One branch per spec. One ticket per session: `/implement #N`.
3. **Ship.** `/code-review` on the branch, PR into `main` (body via the `pr` skill, `Closes #…`), then `/retro`.

Keep sessions short: agents get sloppier as context fills (~125–150K tokens).
One task per session; `/handoff` to continue in a fresh one. One implementing
agent per checkout; use a git worktree for parallel jobs.

## Changing the standards

- **Global rules:** edit `AGENTS.md`. Only rules that apply to every repo; each line costs tokens every session.
- **Stack standards:** edit `standards/<stack>.md`. Repos keep their own copy; to update one, delete its copy and re-run `init-project`.
- **New stack:** add `standards/<stack>.md` and a pointer line in `## Standards` of `project-template/AGENTS.md`.
- **Repo-specific rules:** that repo's `AGENTS.md`.
