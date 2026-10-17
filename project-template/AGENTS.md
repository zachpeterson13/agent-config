# <Project name>

<!--
Project-specific context for Claude and Codex. Extends the team's global
standards and overrides them where they conflict. Loaded every session, so
keep it concise. Fill in every TODO, delete sections that don't apply, then
delete this comment.
-->

## What this is

TODO: What the project does and its business purpose, in one or two sentences.

## Project type

TODO: Web UI / Web API / Windows Service / Windows Application / Console App / Class Library

## Tech stack

TODO: .NET version, front end framework, key libraries and tools.

## Commands

Agents run these before calling work done.

| Purpose | Command |
|---|---|
| Restore | `dotnet restore` |
| Build | `dotnet build` |
| Format check | `dotnet format --verify-no-changes` |
| Test (all) | `dotnet test` |
| Test (one class) | `dotnet test --filter FullyQualifiedName~<ClassName>` |
| Run locally | TODO |

<!-- Adjust to the solution (e.g. add the .sln path) and add npm commands for front ends. -->

## Project structure

TODO: Solution layout, one line per project/folder, and which layer it belongs to.

## Design patterns

TODO: Patterns in use and why (e.g. Repository, CQRS with MediatR).

## Database

TODO: Database technology, ORM, migration strategy and how to run migrations. Delete if none.

## Configuration keys

TODO: Required settings and what each does. Note which are secrets and where they come from.

## Testing approach

TODO: Extra frameworks beyond xUnit/Moq, integration test strategy, coverage targets.

## Known constraints

TODO: Any deviations from the global standards, and why. Delete if none.

## Environment setup

TODO: How to get the project running locally from a fresh clone.

## Domain language

Terms are defined in `GLOSSARY.md`. Decisions are in `docs/adr/`.
