# ADR 0001: Monorepo structure

- Status: Accepted
- Date: 2026-07-23

## Context

Pneuman expects multiple related Business Central integrations for Insight
Works Product Configurator. They need common governance without becoming one
inseparable extension.

## Decision

Keep independently deployable apps below `apps/`, with repository-wide
documentation and review policy at the root. Do not create empty future apps or
a shared AL app until real consumers justify them.

## Consequences

Each app retains its own `app.json`, symbols, analyzer settings, ruleset,
version, and release validation. The root workspace can open multiple app
folders. Cross-app dependencies must be deliberate and documented.
