# AL coding standards

These standards apply equally to human- and AI-generated AL. Compilation is a
minimum requirement, not proof of correct design or behavior.

## Source layout

- Use one AL object per file.
- Include the object name and type in the file name, using suffixes such as
  `.Codeunit.al`, `.TableExt.al`, `.PageExt.al`, `.EnumExt.al`, and
  `.PermissionSet.al`.
- Organize source in feature- or responsibility-based folders.
- Never leave backup, copy, or abandoned files ending in `.al` in an app.
- Every Product Configurator Enhancements object uses namespace
  `Pneuman.ProductConfigurator`.
- Every Frame Specification object uses namespace
  `Pneuman.FrameSpecification`.
- Keep Microsoft `using` directives ordered and verify their namespaces against
  the exact dependency symbols. AA0247 is an Error.

## Object structure

Use this order:

1. Properties.
2. Object-specific declarations such as fields, layout, actions, and triggers.
3. Global variables: labels, records/codeunits/pages, then primitive values in
   the order required by CodeCop.
4. Procedures.

## Variables

- Use PascalCase and meaningful domain names.
- Prefix temporary records with `Temp`.
- Include the represented object in Record, Page, and Codeunit variable names.
- Order declarations by the type order required by CodeCop AA0021 and remove
  unused variables. AA0021 does not mean alphabetical identifier ordering.
- Follow AA0072, AA0073, and AA0074 for object/type suffixes, temporary-record
  prefixes, and Label/TextConst suffixes.
- Avoid cryptic third-party prefixes and new abbreviations unless they are
  established Business Central terms.
- Keep local variables in the smallest practical scope.
- Preserve `var` semantics in events and integrations.

Existing protected-dependency parameter naming may remain during
behavior-preserving work; rename it only as a deliberate, reviewed cleanup.

## Procedures and control flow

- Give each procedure one clear responsibility and an intent-revealing name.
- Prefer early exits over deep nesting.
- Review procedures with more than two or three nested control-flow levels.
- Extract large procedures along domain boundaries, not arbitrary line counts.
- Use Boolean returns when failure is expected; use `Error` only when the
  transaction must stop.
- Use Labels for user-facing messages.
- Preserve validation, insert/modify/delete triggers, and transactional
  behavior explicitly.

## Event subscribers

- Keep subscribers thin: eligibility checks followed by delegation.
- Do not put recursive calculations, page workflows, or large business
  processes in subscribers.
- Never invent a subscriber signature. Inspect the exact dependency symbols,
  including `var` parameters, before subscribing.

## Architecture

- UI objects contain UI behavior, not core calculations.
- Production BOM costing belongs in Production BOM Cost Management.
- Direct Insight Works field mapping belongs in the IWX adapter/integration
  layer.
- Pricing belongs in a pricing management codeunit.
- Rule Engine behavior belongs in a dedicated future module.
- Do not scatter external IWX table access or duplicate business rules.
- Maintain one authoritative procedure for each calculation.

## Business Central practices

- Reference objects by name and scope, such as `Database::`, `Codeunit::`,
  `Page::`, and `Enum::`, rather than literal object numbers.
- Set `DataClassification` on created fields and `ApplicationArea` where
  required.
- Define permission sets for created data objects and consider permissions when
  calling protected platform functionality.
- Be explicit about `Insert`, `Modify`, `Delete`, validation, and trigger
  execution.
- Do not add `Commit()` without a documented transactional reason.
- Do not assume records, external calls, or lookups succeed. Avoid swallowing
  errors silently.
- Avoid unnecessary database reads in loops and use `FindSet` for iteration.
- Use `SetLoadFields` only for a demonstrated material hot path, not as
  cargo-cult optimization.

## Comments and dependency documentation

Comments explain constraints, external behavior, and why a workaround exists;
they do not narrate obvious statements. Document IWX assumptions in
`dependencies.md` and preserve the current-session Choice Code explanation.
Never copy copyrighted Insight Works source into this repository.

## Project-specific invariants

- Never change the app ID or an existing object ID without explicit approval.
- Production BOM Additional Choices create permanent IWX Option Choices of type
  `Production BOM`.
- Do not validate `Choice Code` immediately in an already-open session unless
  the stale lookup is also updated.
- Do not let Extended Details interpret a Production BOM as an Item.
- IWX owns inventory cost; custom code adds only missing Non-Inventory cost.
- Never double-count inventory cost.
- Keep nested BOM traversal recursive and bounded by circular-reference
  detection.
- Keep Unit Cost visible immediately and leave Unit Price unchanged unless a
  separately approved pricing feature requires otherwise.

## AI-generated code review

Compare generated code with architecture and behavior documentation. Check
transactions, triggers, duplicate calculations, recursion termination,
dependency assumptions, and failure paths. Remove abandoned experiments and
duplicate backups. Never accept a change solely because it compiles.
