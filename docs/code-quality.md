# AL code quality

## Tool responsibilities

This is an AL repository. C# Roslyn analyzers, StyleCop.Analyzers, and
SonarAnalyzer.CSharp do not analyze AL and are not part of the quality system.

- The **AL compiler** detects syntax, type, symbol, and object errors.
- **CodeCop** applies Microsoft's AL coding and readability diagnostics.
- **UICop** detects unsupported or undesirable Business Central Web Client UI
  patterns.
- **PerTenantExtensionCop** checks constraints relevant to private per-tenant
  SaaS extensions.
- **AppSourceCop** is disabled because this app is not currently submitted to
  Microsoft Marketplace.
- The **AL Formatter** performs mechanical formatting; it does not make
  architecture or correctness decisions.

## Configuration

App-level settings and rulesets live below every AL project root. They enable
full-project background analysis, code actions, an explicit local symbol cache,
CodeCop, UICop, and PerTenantExtensionCop. Each app owns its namespace template
and `config/PNE.ruleset.json`.

`PNE-IWX-Extensions.code-workspace` is the authoritative multi-root workspace.
It loads all three apps, recommends only the official Microsoft AL Language
extension, and provides setup and validation tasks. Opening only one app does
not constitute repository-wide validation.

## Rules and severities

Analyzer defaults remain in force unless the ruleset names a specific rule. The
ruleset promotes AA0021, AA0072, AA0073, AA0074, AA0215, and AA0247 to Error.
These are verified Microsoft declaration, naming, temporary-record, label,
file/object-name, and namespace requirements. AA0021 is ordering by AL type,
not alphabetical identifier ordering.

The standard validation uses the compiler's warnings-as-errors option, so every
other compiler or analyzer Warning also fails the build. Informational rules are
not promoted indiscriminately. No blanket `None` entry is allowed. Any future
exception must target one rule, include a justification, be recorded in
`analyzer-baseline.md`, and receive explicit review.

## Local build and diagnostics

Follow `development-setup.md`. Run the Microsoft AL formatter on changed files,
then execute `scripts/Test-AlDevelopmentEnvironment.ps1` and
`scripts/Invoke-AlValidation.ps1`. The scripts locate the installed official AL
compiler dynamically, validate exact local symbols per app, run all three PTE
analyzers, treat warnings as errors, and create ignored package and diagnostic
output below each app's `.build` folder. They never publish or authenticate.

## Baseline and quality gate

The active gate is zero compiler errors, zero analyzer errors, zero warnings,
and a documented explanation for every Info diagnostic. First record diagnostic
codes, then fix safe mechanical findings and handle architectural debt through
focused changes with tests. Never suppress a diagnostic merely to make output
appear clean.

## Future CI

A future pull-request workflow can call the same checked-in validation scripts
after acquiring a verified AL toolchain and exact licensed symbols. CI must not
embed tenant credentials or redistribute proprietary symbols.

## Business Central safety policy

Codex may inspect, document, format, refactor, and locally compile source. It
must not change any Business Central environment without explicit approval in
the current conversation.

Without that approval, the following are forbidden:

- publishing with F5, `AL: Publish`, `al_publish`, or another publisher;
- installing, upgrading, or uninstalling an extension;
- deleting extension data or executing data migration/upgrade code;
- ForceSync or another destructive schema synchronization;
- targeting production or changing launch configuration to production;
- changing tenant or environment identifiers;
- increasing the application version for deployment;
- adding `Commit()`;
- deleting tables or table-extension fields;
- changing field IDs, field types, existing app IDs, or object IDs; and
- pushing or merging changes.

Development and validation target Sandbox only. Production tenant configuration
must never be stored in the repository.

### Change preparation

Before every non-trivial code change:

1. Confirm the current working source is committed.
2. Create or use a dedicated branch.
3. Describe intended behavior and affected objects.
4. Identify database, trigger, and transaction risks.
5. Keep the change narrowly scoped.
6. Compile locally.
7. Run analyzers.
8. Inspect the full Git diff.
9. Report required manual Sandbox tests.
10. Stop before publishing.

### Refactor safety

A refactor cannot change observable behavior and cannot be combined with new
functionality. Preserve event signatures and `var` semantics, validation
triggers, `Insert(true)`, `Modify(true)`, Delete trigger behavior, significant
field assignment order, transaction boundaries, recursive BOM behavior,
circular-reference protection, the current-session IWX lookup workaround, IWX
inventory-cost calculation, and the custom Non-Inventory cost addition.

### Schema safety

Every table, table extension, and field change is a database migration. Before
one is proposed, report affected table and field IDs, existing-data risk,
upgrade compatibility, uninstall behavior, and rollback limitations, then
obtain explicit approval. Never use ForceSync and never delete extension data.

### Production safety

Codex must not interact with a production Business Central environment.
Production deployment is a separate manual release step after successful
compilation, analyzer and Git review, Sandbox tests, documented regression
results, a versioned package, and explicit human approval. If potential
Business Central impact is uncertain, stop and ask.
