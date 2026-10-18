# Delegation mode: Claude

<!-- Loaded instead of delegation-codex.md for developers who chose Claude. Switch by re-running the install script with -Delegation codex (--delegation codex). -->

This developer's workers are **Claude subagents**. Every worker's tokens count against the same capped budget as this session, so the workflow's discipline matters even more here.

- **Implementation, tests, bugs, exploration, research:** spawn a Claude subagent with a self-contained brief. Still never do this work in the main session: the subagent gets a fresh context and the main session stays small.
- **Use a smaller model for workers.** When your subagent tool lets you choose a model, use `sonnet` for implementation, test, and exploration subagents, and keep the main session for planning and judgment. The developer can ask for a stronger model for a hard task.
- **Skills that spawn subagents** (`implement`, `implement-spec`, `code-review`, `wayfinder`, and others) work as written.
- **Review:** `/code-review` covering the diff since the branch point from `dev`. For risky changes (auth, data migrations, anything hard to roll back), also brief a separate reviewer subagent to challenge the design: assumptions, failure modes, and safer alternatives.
- **Spend carefully:** keep briefs narrow, don't re-run full reviews, and batch trivial fixes into one worker task.
- **Don't use `/codex:*` commands** unless the developer asks for one on a specific task.
