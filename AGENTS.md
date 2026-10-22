Windows host: PowerShell primary, Git Bash available. Use forward slashes in bash.

# Standards

**Precedence:** the repo's `AGENTS.md` overrides this file where they conflict. Explicit
instructions from the developer in the current session override both.

## Engineering principles

- Keep it simple; don't build what isn't needed yet. SOLID in object-oriented code.
- Keep business logic, data access, and presentation separate.
- Fail fast: validate all input at the application boundary and surface errors clearly. Never swallow errors silently.
- Use descriptive names without abbreviations. No magic strings or numbers.
- Comments explain **why**, not what. No commented-out code; version control keeps history.

## Testing

- Business logic has automated tests that cover edge cases and failures, not just the happy path.
- Tests are independent of each other and follow Arrange / Act / Assert.
- Test infrastructure (databases, file system, external services) with integration tests, not unit tests.

## Security and configuration

- Never commit secrets, credentials, or environment-specific config. Secrets come from environment variables, a secrets manager, or GitHub Actions secrets.
- No hardcoded connection strings, keys, or environment-specific values in code.
- Never log passwords, tokens, or PII.
- Apply least privilege to service accounts and database users.
- Don't add a dependency without a reason stated in the PR description.

## Source control (GitHub)

- Repos are on **GitHub**. Use `gh` for issues and pull requests.
- Branch types: `feature/`, `bugfix/`, `chore/`, with a short slug: `feature/order-export`. Add the issue number when there is one: `feature/14-order-export`.
- Work branches merge into `main` via pull request. No direct commits to `main`.
- Commit messages explain what changed and why. Reference issues where they exist: `Add CSV writer (#14)`.
- PR descriptions list `Closes #…` for every issue completed.
- GitHub Actions handle build, test, and deployment.

## Working rules for agents

- The developer drives the process. Do the task you're given. Don't start, skip, or chain workflow steps (planning, specs, tickets, reviews, handoffs) or hand work to another agent unless asked.
- Before writing or reviewing code, read the standards file(s) the repo's `AGENTS.md` points to for that code.
- Before calling work done, run the repo's build, format/lint, and test commands (listed in its `AGENTS.md`) and report the results.
- Prefer a small vertical slice that runs over a broad change that doesn't.
- One task per session. If a task is too big to finish cleanly, stop at a working point and report what's done and what's left.
- Commit on your working branch as needed. Never push or merge without being asked. Keep commit messages concise, prefer just a header/title if possible. If a body is required keep it short (~3 lines).
