# Blu Ace delivery — Pneuman IWX extensions

This folder is a self-contained source delivery for Blu Ace. It contains only
what is needed to review, compile, modify, test, and package the extension. It
does not include Pneuman's agent instructions, Git history, internal use cases,
downloaded symbols, local launch settings, generated packages, or credentials.

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

## Frame Specification template

Report 50158 `PNE Frame Specification` uses the Word template
`PNE.FrameSpecification/Layouts/PNEFrameSpecification.docx`. It is registered
as a Word rendering layout and can be replaced or customized through standard
Business Central report-layout selection without changing AL code.

## Build handover

1. Open the required app folder as the AL project folder in VS Code.
2. Install or select a Business Central 28/runtime 17-compatible AL Language
   extension.
3. Acquire symbols for the exact Product Configurator and, for Product
   Configurator Enhancements, Blue Ace versions in the relevant `app.json`; do
   not copy symbols from this delivery.
4. Run the AL formatter on changed AL files and package with CodeCop, UICop,
   and PerTenantExtensionCop enabled by `.vscode/settings.json`.
5. Resolve every compiler error and report all remaining diagnostics. Perform
   the relevant Sandbox tests in `docs/test-plan.md` before release.

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
