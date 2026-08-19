# Blu Ace delivery — Pneuman IWX extensions

This folder is a self-contained source delivery for Blu Ace. It contains only
what is needed to review, compile, modify, test, and package the extension. It
includes delivery-scoped agent quality instructions, but not Pneuman's internal
use cases, downloaded symbols, local launch settings, generated packages, or
credentials. A clean exported archive does not include Git history.

## Contents

- `PNE.ProductConfiguratorEnhancements/`: compile-ready AL project, including
  `app.json`, AL source, analyzer settings, and the app's technical README.
- `PNE.FrameSpecification/`: compile-ready AL project for the released
  production-order frame-specification report, including its Word layout
  `Layouts/PNEFrameSpecification.docx`.
- `docs/partner-installation-guide.md`: installation, configuration, and
  acceptance handover.
- `docs/functional-specification.md`: business purpose, functional behavior,
  limits, and upgrade impact.
- `docs/current-behavior.md`: implementation-accurate behavior and edge
  cases.
- `docs/dependencies.md`: exact dependency identities and public symbols.
- `docs/test-plan.md`: Sandbox regression and acceptance scenarios.
- `docs/iwx-business-rules-compatibility.md`: compatibility boundary proving
  that neither app changes, deletes, suppresses, or reimplements Insight Works
  Product Configurator Business Rules.
- `docs/transfer-audit.md`: source-audit result, reviewed IWX writes and
  `IsHandled` paths, and remaining Sandbox acceptance evidence.
- `docs/frame-specification.md` and `docs/frame-specification-test-plan.md`:
  Frame Specification data ownership, Word-layout information, and required
  Sandbox acceptance scenarios.

## Insight Works Business Rules compatibility

Both apps leave Insight Works Business Rule definitions and evaluation
lifecycle under IWX ownership. Product Configurator Enhancements uses only
public extension points and does not handle Business Rule events. Frame
Specification has no event subscribers; it reads configuration data into
temporary buffers and does not modify Product Configurator records. Its frame
rules are Pneuman-owned report configuration, not IWX Business Rules.

Product Configurator Enhancements can optionally map an exact Config. Template
Item Disc. Group placeholder such as `{I_FA}` to the selected IWX Choice Code.
The mapping occurs before standard Config. Template validation. It reads, but
never changes, the IWX Data Template and Business Central Config. Template
Line, and does not handle a Business Rule event.

## Frame Specification template

Report 50158 `PNE Frame Specification` uses the Word template
`PNE.FrameSpecification/Layouts/PNEFrameSpecification.docx`. It is registered
as a Word rendering layout and can be replaced or customized through standard
Business Central report-layout selection without changing AL code.

## Build handover

1. Review the source, then grant Workspace Trust only if appropriate.
2. Open `PNE-IWX-Extensions.code-workspace` and install the recommended official
   Microsoft AL Language extension.
3. Run `AL: Setup check`.
4. Download exact symbols separately for each app as described in
   `docs/development-setup.md`; do not copy symbols from this delivery.
5. Run the Microsoft AL formatter on changed files and the default
   `AL: Validate all PTE apps` task.
6. Require zero errors and warnings from CodeCop, UICop, and
   PerTenantExtensionCop and report every Info diagnostic.
7. Perform and retain the relevant Sandbox tests before release.

No package is supplied in this source delivery. Build a new package from the
reviewed source, preserve the app ID and all existing object/field IDs, and do
not publish, install, upgrade, or target production without the applicable
release approval.

## Updating this delivery

Treat this folder as an export, not as Pneuman's development source of truth.
If Blu Ace returns changes, merge them into the main repository through a
normal review, compile, and Sandbox-validation process. Create a fresh export
after the reviewed change; do not copy local symbol folders, `.app` files,
launch settings, credentials, or unrelated internal documentation into it.

This directory can contain ignored local artifacts on a development machine.
Never create the handover by zipping the working directory in File Explorer.
After committing the reviewed delivery state, export tracked files only:

```powershell
git archive --format=zip --output PNE-IWX-Extensions-partner-delivery.zip HEAD
```

Inspect the archive contents before transfer. It must not contain `.git`,
`.app`, `.alpackages`, `.build`, snapshots, `launch.json`, `rad.json`, or
credentials.
