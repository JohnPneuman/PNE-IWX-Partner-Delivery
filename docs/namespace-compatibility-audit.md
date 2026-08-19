# Namespace compatibility audit

## Decision

Namespaces were introduced as an explicitly approved compatibility change:

- `Pneuman.ProductConfigurator` for PNE Product Configurator Enhancements;
- `Pneuman.FrameSpecification` for PNE Frame Specification.

Every AL object is in its app namespace and AA0247 is promoted to Error so new
objects cannot silently return to the global namespace.

## Repository impact

- Neither app depends on the other app ID.
- No AL consumer of either app ID exists in this repository.
- App IDs, object IDs, field IDs, field types, table keys, event attributes,
  procedure names, parameter types, `var` semantics, and transaction behavior
  were not changed.
- No database schema or stored data was changed.
- Microsoft object namespaces were taken from the exact Business Central 28.3
  symbol packages used for compilation and added as ordered `using` directives.
- Insight Works and Blue Ace symbols remain referenced through their published
  symbol names; their objects currently reside in the global namespace.

## External compatibility risk

An external AL project that consumes a public object from either app may need a
`using Pneuman.ProductConfigurator;` or
`using Pneuman.FrameSpecification;` directive when it is recompiled. Existing
compiled references and upgrades still require Sandbox validation; this audit
cannot prove that an unknown external source consumer does not exist.

Before a release:

1. ask the receiving partner whether another extension depends on either PNE
   app ID;
2. compile every known consumer against the newly generated symbol package;
3. publish and upgrade only in a representative Sandbox with normal schema
   synchronization, never ForceSync;
4. confirm existing extension data remains present;
5. execute both app test plans and existing IWX Business Rules regression tests;
6. retain the compile, upgrade, and Sandbox evidence with the release decision.

Production publication, installation, or upgrade is not authorized by this
audit.
