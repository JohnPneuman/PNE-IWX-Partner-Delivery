# ADR 0001: Monorepo structure

- Status: Accepted
- Date: 2026-07-23

## Context

Pneuman expects multiple related Business Central integrations for Insight
Works Product Configurator. They need common governance without becoming one
inseparable extension.

## Decision

Keep independently deployable app projects at the repository root in this
self-contained partner delivery, with repository-wide documentation and review
policy beside them. Do not create empty future apps or a shared AL app until
real consumers justify them. Pneuman's internal development repository may use
an `apps/` container; that internal layout is deliberately not exported here.

## Consequences

Each app retains its own `app.json`, symbols, analyzer settings, ruleset,
version, and release validation. The root workspace can open multiple app
folders. Cross-app dependencies must be deliberate and documented.
