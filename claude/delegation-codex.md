# Delegation mode: Codex

<!-- Loaded instead of delegation-claude.md for developers who chose Codex. Switch by re-running the install script with -Delegation claude (--delegation claude). -->

This developer's workers are **Codex agents**. Codex usage is effectively unlimited; Claude usage is not.

- **Implementation, tests, bugs, exploration, research:** the `codex:codex-rescue` subagent (equivalent to `/codex:rescue`). Run long tasks with `--background` and check in with `/codex:status` and `/codex:result`.
- **Review:** `/codex:review --base dev` for standard review. Add `/codex:adversarial-review --base dev` for risky changes (auth, data migrations, anything hard to roll back). If you can't run these yourself, ask the developer to.
- **Skills that spawn subagents** (`implement`, `implement-spec`, `code-review`, `wayfinder`, and others): **always use `codex:codex-rescue` for those subagents, never a Claude subagent.** Keep following the skill's process otherwise.
- **If Codex isn't available** (not installed, not logged in, an outage): tell the developer and ask whether to use a Claude subagent for this task. Don't switch on your own: it spends their Claude budget.
