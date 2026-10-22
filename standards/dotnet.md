# .NET standards

<!-- Copied from agent-config/standards/dotnet.md by init-project. Agents read this only when working on C#/.NET code, via the pointer in AGENTS.md. Delete sections that don't apply to this repo. -->

## Architecture

Keep clear layers where applicable:

- **Presentation**: UI, controllers, console entry points. No business logic.
- **Application**: orchestration of business operations, use cases, and workflows
- **Domain**: core business entities, rules, and logic. No dependencies on infrastructure.
- **Infrastructure**: database access, file system, external APIs, messaging

Dependencies only point **inward**: Infrastructure → Application → Domain. Domain depends on nothing outside itself.

## C# conventions

- **PascalCase**: classes, methods, properties, constants, enums. **camelCase**: locals and parameters. **_camelCase**: private fields. **IPascalCase**: interfaces.
- Target the **latest LTS .NET** unless the repo's `AGENTS.md` says otherwise.
- Enable `<Nullable>enable</Nullable>` and `<ImplicitUsings>enable</ImplicitUsings>`.
- **async/await** for all I/O-bound operations. No blocking calls.
- **Constructor injection** for all dependencies. No service locator.
- Every public-facing service and component has an **interface**.
- Prefer expression-bodied members for simple single-line properties and methods.
- Use **record types** for immutable DTOs and value objects.
- XML documentation comments (`///`) on all public classes and methods.

## Error handling

- Centralized exception handling suited to the project type: global middleware (Web APIs), structured logging with restart policies (Windows services), top-level try/catch with meaningful exit codes (console apps).
- Log all unhandled exceptions before the application exits.
- Use the **Result pattern** for business rule failures rather than throwing exceptions.

## Logging

- **Serilog**, structured. Console sink in development; file or other sink in production.
- Levels: `Verbose`/`Debug` for development diagnostics only; `Information` for normal flow milestones; `Warning` for recoverable surprises; `Error` for a failed operation; `Fatal` for failures that terminate the application.
- Include contextual properties (e.g. user ID, request ID, trade number).

## Configuration

- Use the **Options pattern** (`IOptions<T>`) for strongly typed configuration.
- Use environment-specific files (`appsettings.Development.json`, etc.) for local overrides.

## Database

- Tables **PascalCase, plural** (`Users`, `OrderItems`); columns **PascalCase**; primary keys `Id`; foreign keys `{TableName}Id`; indexes `IX_{TableName}_{ColumnName}`.
- Every table has a primary key and `CreatedAt` / `UpdatedAt` audit columns.
- Use soft deletes (`IsDeleted`) where data retention is required.
- **Parameterized queries only.** Never concatenate user input into SQL.
- No `SELECT *`. Select only the columns needed.
- All schema changes go through **migrations**. No manual changes in production.

## Testing

- **xUnit** for tests, **Moq** for mocks.
- Test names: `MethodName_Condition_ExpectedResult`.
- Unit tests cover all business logic in the Domain and Application layers.

## Web and auth

- HTTPS for all web-facing communication.
- Store passwords with a strong hashing algorithm, never in plain text.
