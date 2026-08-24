# Repository architecture

## Monorepo rationale

PNE-IWX-Extensions groups related Pneuman integrations for Insight Works
Product Configurator while retaining deployable AL app boundaries. A monorepo
allows shared review standards, documentation, and future CI without forcing
unrelated functionality into one Business Central extension.

Each app has its own project folder directly below the delivery root:
`PNE.FrameSpecification`, `PNE.ProductConfiguratorEnhancements` and
`PNE.ProductionOrderReconciliation`. The folder containing `app.json` is the AL
project root. Source is organized by responsibility below `src/`; app-specific
analyzer configuration belongs to that app. Repository-wide documentation,
review policy and the VS Code workspace remain at the delivery root.

Empty applications are not created for roadmap items. Shared compiled AL
functionality will not become a shared app until at least two real applications
need the same behavior and its dependency/versioning cost is justified.

## Folder conventions

- `.agents/skills/`: repository-local Business Central quality instructions for
  coding agents.
- `PNE.FrameSpecification/`, `PNE.ProductConfiguratorEnhancements/` and
  `PNE.ProductionOrderReconciliation/`: independently versioned AL
  applications.
- `docs/`: architecture, behavior, dependencies, quality, testing, and ADRs.
- `docs/decisions/`: durable architecture decisions.
- `scripts/`: read-only setup checks and local analyzer-enabled validation; no
  publishing or environment mutation.

`PNE-IWX-Extensions.code-workspace` is the authoritative multi-root delivery
entry point and includes all three AL project roots.

Downloaded symbols, output packages, snapshots, and tenant launch configuration
remain local to an app and are ignored.

## Branch and release strategy

`main` is the stable integration branch. Development should use short-lived
feature or fix branches and pull requests. Force pushes to shared branches are
not part of the normal workflow.

Each app owns its `app.json` version. A release changes only the versions of
apps that actually changed, records notable changes in the changelog, compiles
with the supported dependency versions, and completes the relevant test plan.
Repository tags should identify both app and version when multiple apps exist.
