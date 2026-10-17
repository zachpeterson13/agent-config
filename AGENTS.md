# Global Development Standards

Team-wide engineering standards for **all projects**. Read by both Claude Code and Codex.
Each project extends these in its own root `AGENTS.md` with project-specific context, technology
choices, and conventions.

**Precedence:** a project's `AGENTS.md` overrides this file where they conflict. Explicit
instructions from the developer in the current session override both.

## Project types

The team builds: Web UI (Angular, React, Blazor), Web APIs (ASP.NET Core REST), Windows
applications (WPF, WinForms), Windows services (background services, scheduled jobs), console
applications (CLI tools, batch processors, utilities), and class libraries.

## General engineering principles

- **SOLID**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **DRY**: extract shared logic into reusable methods, classes, or libraries
- **KISS**: prefer the straightforward approach over clever or overly abstract solutions
- **YAGNI**: don't build features or abstractions that aren't currently needed
- **Separation of concerns**: keep business logic, data access, and presentation in distinct layers
- **Fail fast**: validate inputs early and surface errors clearly

## Architecture

Every project keeps clear layers where applicable:

- **Presentation**: UI, controllers, console entry points. No business logic.
- **Application**: orchestration of business operations, use cases, and workflows
- **Domain**: core business entities, rules, and logic. No dependencies on infrastructure.
- **Infrastructure**: database access, file system, external APIs, messaging

Dependencies only point **inward**: Infrastructure → Application → Domain. Domain depends on nothing
outside itself. The project's `AGENTS.md` lists which design patterns it uses (e.g. Repository,
CQRS with MediatR, Factory/Builder, event-driven).

## C# .NET coding standards

### Naming
- **PascalCase**: classes, methods, properties, constants, enums
- **camelCase**: local variables, method parameters
- **_camelCase**: private fields
- **IPascalCase**: interfaces
- Names are descriptive and meaningful. Avoid abbreviations.

### General rules
- Target the **latest LTS .NET** unless the project says otherwise
- Enable `<Nullable>enable</Nullable>` and `<ImplicitUsings>enable</ImplicitUsings>` in all projects
- Use **async/await** for all I/O-bound operations. No blocking calls.
- Use **constructor injection** for all dependencies. No service locator.
- Every public-facing service and component has a corresponding **interface**
- No magic strings or numbers. Use constants, enums, or configuration.
- Keep methods short and focused on one thing
- Prefer expression-bodied members for simple single-line properties and methods
- Use **record types** for immutable DTOs and value objects

### Error handling
- Centralized exception handling suited to the project type: global middleware (Web APIs), structured logging with restart policies (Windows services), top-level try/catch with meaningful exit codes (console apps)
- Never swallow exceptions with an empty catch block
- Log all unhandled exceptions before the application exits
- Use the **Result pattern** for business rule failures rather than throwing exceptions

### Comments and documentation
- XML documentation comments (`///`) on all public classes and methods
- Inline comments explain **why**, not what
- No commented-out code. Use version control instead.

## Logging

- **Serilog** in every project, with structured logging
- Console sink in development; file or other sink in production
- Levels: `Verbose`/`Debug` for development diagnostics only; `Information` for normal flow milestones; `Warning` for recoverable surprises; `Error` for a failed operation; `Fatal` for failures that terminate the application
- Include contextual properties (e.g. user ID, request ID, trade number)
- Never log passwords, tokens, or PII

## Configuration

- Use the **.NET Options pattern** (`IOptions<T>`) for strongly typed configuration
- No hardcoded connection strings, API keys, or environment-specific values in code
- Use environment-specific files (`appsettings.Development.json`, etc.) for local overrides
- Secrets come from environment variables or a secrets manager, never source control
- The project's `AGENTS.md` documents its required configuration keys

## Database

For projects that use a relational database:

- Tables **PascalCase, plural** (`Users`, `OrderItems`); columns **PascalCase**; primary keys `Id`; foreign keys `{TableName}Id`; indexes `IX_{TableName}_{ColumnName}`
- Every table has a primary key and `CreatedAt` / `UpdatedAt` audit columns
- Use soft deletes (`IsDeleted`) where data retention is required
- **Parameterized queries only.** Never concatenate user input into SQL.
- No `SELECT *`. Select only the columns needed.
- All schema changes go through **migrations**. No manual changes in production.
- The project's `AGENTS.md` names the ORM and migration strategy

## Testing

- All business logic in the Domain and Application layers has unit tests
- **xUnit** for tests, **Moq** for mocks
- Arrange / Act / Assert in every test
- Test names: `MethodName_Condition_ExpectedResult`
- Tests are independent. No test depends on state left by another.
- Cover edge cases and failure scenarios, not just the happy path
- Don't unit test infrastructure (database, file system); use integration tests for those. Skip simple pass-through code.
- The project's `AGENTS.md` lists extra frameworks, integration test strategy, and coverage targets

## Security

- Validate and sanitize all input at the application boundary
- Parameterized queries to prevent SQL injection
- Least privilege for service accounts and database users
- Keep NuGet and npm dependencies up to date
- Mask or omit PII, tokens, and credentials in all logs
- HTTPS for all web-facing communication
- Store passwords with a strong hashing algorithm, never in plain text

## Source control (GitLab)

- All projects are on **GitLab**. Use `glab` for issues and merge requests, not `gh`. Say "merge request" (MR), not "pull request".
- Branches: `feature/`, `bugfix/`, `hotfix/`, `chore/` for development, named `<type>/<issue-number>-<short-slug>` (e.g. `feature/123-order-export`)
- Promotion flow: `feature/*` → `dev` → `qa` (UAT) → `prod`. `prod` only takes merges from `qa` after sign-off.
- No direct commits to `dev`, `qa`, `prod`, `main`, or `master`. All changes go through reviewed and approved MRs. Feature branches target `dev`.
- Commit messages explain what changed and why, and reference the issue (e.g. `#123`)
- Specs and tickets live as GitLab issues
- GitLab CI/CD pipelines handle build, test, and deployment. Secrets live in GitLab CI/CD variables.
- Never commit secrets, credentials, or environment-specific config. Each project has a `.gitignore` for its project type.

## Working rules for agents

- Before calling work done, run the project's build, format/lint, and test commands (listed in its `AGENTS.md`) and report the results
- Take small steps. Prefer a vertical slice that runs over a broad change that doesn't.
- Work on one task per session. If a task turns out too big to finish cleanly in one session, stop at a working point and report what's done and what's left, rather than pushing on with a bloated context.
- Use the project's `GLOSSARY.md` terms in code, comments, and messages. Don't invent synonyms.
- Record decisions that are hard to reverse or hard to explain as ADRs in `docs/adr/`
- Never push or merge without being asked
