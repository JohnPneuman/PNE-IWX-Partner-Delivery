# Codex working instructions

For every AL implementation, review, refactor, build, analyzer, symbol, or
Business Central development-environment task, use the repository skill at
`.agents/skills/business-central-al-quality/SKILL.md`. The skill is part of the
quality gate, not optional background reading.

Before editing, read the relevant repository documentation:

- `docs/repository-architecture.md`
- `docs/application-architecture.md`
- `docs/coding-standards.md`
- `docs/code-quality.md`
- `docs/dependencies.md`
- `docs/current-behavior.md`
- `docs/test-plan.md`
- `docs/review-checklist.md`
- `docs/analyzer-baseline.md`

Inspect the affected `app.json` and dependency symbols before changing AL. Make
a plan for non-trivial changes, keep the scope narrow, and preserve the app ID,
existing object IDs, trigger behavior, transaction behavior, and documented
working functionality.

Use one AL object per correctly named file. Keep event subscribers thin,
business logic in management codeunits, and direct Insight Works mappings in
the adapter/integration layer. Never invent external fields, objects, or event
signatures.

Open `PNE-IWX-Extensions.code-workspace`, not only the repository root. Run
`scripts/Test-AlDevelopmentEnvironment.ps1` before non-trivial AL work. Run the
AL formatter on changed AL files, then run
`scripts/Invoke-AlValidation.ps1`. The validation must compile all three apps with
CodeCop, UICop, and PerTenantExtensionCop enabled and warnings treated as
errors. Report compiler/analyzer versions, every remaining diagnostic, and the
diagnostic-log paths. Never disable analyzers or add undocumented suppressions
merely to finish.

The current distribution model is PTE. Use CodeCop and UICop plus exactly one
distribution analyzer: PerTenantExtensionCop for this repository. Do not enable
AppSourceCop at the same time. A Marketplace migration requires an explicit
distribution decision, replacement of PerTenantExtensionCop by AppSourceCop,
an `AppSourceCop.json`, a compatibility baseline, registered affixes and object
ranges, and a separate validation plan.

CodeCop AA0021 orders variable declarations by AL type; it does not require
alphabetical variable names. Treat an alphabetical rule as a partner rule only
when its diagnostic source and code are recorded. The repository ruleset
promotes the verified Microsoft naming and declaration diagnostics. The
command-line validation treats every remaining Warning as an Error.

Leave no backup `.al` files, generated `.app` packages, symbols, credentials,
or third-party source in version control. Update documentation when behavior,
architecture, dependencies, or quality exceptions change. Never push or
publish without explicit approval.

## Business Central safety

Development and testing are Sandbox-only. Never target production, store
production tenant configuration, use ForceSync, delete extension data, or
publish, install, upgrade, or uninstall an extension without explicit approval
in the current conversation. Never add `Commit()` without explicit approval.

Treat any table, table extension, field ID, field type, or field removal change
as a database migration requiring a separate risk report and explicit approval.
Do not combine refactoring with new functionality.

Before non-trivial code work, confirm the working source is committed, use a
dedicated branch, describe affected behavior and objects, identify database,
trigger, and transaction risks, keep scope narrow, compile locally, run
analyzers, inspect the full diff, report required Sandbox tests, and stop before
publishing.

A refactor must preserve event signatures and `var` semantics, validation and
database triggers, `Insert(true)`/`Modify(true)`/Delete behavior, significant
assignment order, transaction boundaries, recursive BOM and cycle protection,
the current-session IWX workaround, IWX inventory cost, and the custom
Non-Inventory addition. If an action might affect Business Central and its
impact is uncertain, stop and ask.

## Insight Works Business Rules compatibility

Insight Works Product Configurator Business Rules remain exclusively owned and
evaluated by IWX. Do not create, modify, delete, suppress, or reimplement an
IWX Business Rule, Rule Engine, Rule Builder, rule definition, or rule-action
record unless the user explicitly approves that exact scope after dependency
symbol review.

Do not add an `IsHandled := true` assignment to a Business Rule lifecycle event
or alter its event flow. Before adding an IWX write, event subscriber, or
`IsHandled` assignment, identify whether it can affect Business Rule evaluation.
If that is uncertain, stop and ask. Preserve the existing limited
current-session mapping workaround: it may update the active temporary
Configurator BOM buffer only for its documented session-mapping scenario; it
must not persist or trigger a new rule evaluation.

Pneuman-owned report/calculation rules are not IWX Business Rules, but must be
kept separate in naming, tables, documentation, and tests. For every IWX
integration change, document the compatibility boundary and Sandbox-test that
existing IWX Business Rules continue to behave unchanged.

## Task completion

Close a completed task with the current status and the next logical step. State
which follow-up actions require explicit permission, keep proposing useful next
steps even when they cannot be performed autonomously, and end with a concrete
question when proceeding would be useful. Never push, open a pull request,
publish, install, deploy, pull, or make another external change unless the
current request explicitly authorizes it. Do not force a follow-up question
when the work is genuinely complete and no useful next step remains.

No AL task is complete without all of the following evidence:

1. setup check passed;
2. affected dependency symbols and `app.json` were inspected;
3. formatter ran on every changed `.al` file;
4. all three AL projects completed the standard validation task;
5. CodeCop, UICop, and PerTenantExtensionCop produced no errors or warnings;
6. every informational diagnostic is reported and justified in the baseline;
7. the complete Git diff was inspected;
8. required Sandbox tests and any unexecuted tests were reported; and
9. no package, symbol, launch setting, RAD file, credential, or suppression was
   added to version control.
