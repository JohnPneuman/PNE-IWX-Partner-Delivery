# ADR 0002: IWX adapter layer

- Status: Accepted, implemented
- Date: 2026-07-23

## Context

IWX table fields, validations, enum values, and event signatures are compile-time
external dependencies. Spreading them through unrelated codeunits makes upgrades
risky and encourages accidental behavior changes.

## Decision

Concentrate direct IWX creation, retrieval, validation, and field mapping in an
adapter/integration codeunit, except where subscriber signatures necessarily
expose IWX records. The current-session direct copy remains an explicit adapter
responsibility.

## Consequences

An IWX upgrade has a small compatibility review surface. This does not create
fake runtime aliases for AL symbols. The current behavior was extracted into
the adapter without changing event signatures, validations, trigger execution,
or the direct current-session field-copy workaround.
