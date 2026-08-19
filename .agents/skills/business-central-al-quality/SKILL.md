---
name: business-central-al-quality
description: Enforce the partner delivery's official Microsoft AL development, analyzer, build, symbol, safety, and handover gate. Use for any Business Central AL change, review, refactor, build, diagnostic, VS Code setup, dependency-symbol, namespace, or compatibility task in this delivery.
---

# Business Central AL quality gate

Follow this sequence for every applicable task.

## 1. Establish scope and safety

- Read `AGENTS.md` and the relevant delivery documents.
- Open and inspect every affected `app.json` and the actual dependency symbols.
- Confirm the tracked source is committed, use a dedicated branch, and preserve
  app IDs, object/field IDs, trigger behavior, transactions, `var` semantics,
  database behavior, and documented IWX boundaries.
- Do not publish, install, upgrade, uninstall, sign, push, target production,
  use ForceSync, delete data, or add `Commit()` without current explicit
  permission.
- Treat schema changes and public-symbol compatibility changes as separately
  approved work with a risk report.

## 2. Select analyzers from the distribution model

- Always use CodeCop and UICop.
- This delivery contains private PTE apps, so use PerTenantExtensionCop.
- Never run PerTenantExtensionCop and AppSourceCop together.
- If Marketplace/AppSource is requested, stop and require an explicit migration
  decision before replacing PTECop or creating AppSource configuration. Then
  read `references/microsoft-quality-gates.md`.

## 3. Prepare the development environment

- Use `PNE-IWX-Extensions.code-workspace`; it contains both AL project roots.
- Run `scripts/Test-AlDevelopmentEnvironment.ps1`.
- Let the setup check report missing software or symbols. Never install,
  authenticate, publish, or write credentials silently.
- Download symbols separately for each app into its ignored `.alpackages`
  folder. Use exact versions from `app.json`; never commit or redistribute
  proprietary dependency packages.

## 4. Change narrowly

- Inspect before editing and do not invent external objects, fields, methods,
  events, or signatures.
- Keep one correctly named object per file, subscribers thin, business logic in
  management codeunits, and direct IWX mappings in the adapter layer.
- Apply CodeCop naming literally. AA0021 is declaration ordering by AL type,
  not alphabetical variable-name ordering. Record any partner-specific rule by
  diagnostic code and source instead of presenting it as a Microsoft rule.
- Do not suppress a diagnostic to complete the task. A ruleset exception must
  be specific, justified, documented in `docs/transfer-audit.md`, and
  explicitly approved when it weakens the gate.

## 5. Prove completion

1. Run the AL formatter on every changed `.al` file.
2. Run `scripts/Invoke-AlValidation.ps1` for both apps.
3. Require zero compiler errors and zero analyzer warnings. The script uses
   warnings-as-errors with CodeCop, UICop, and PerTenantExtensionCop.
4. Report every Info diagnostic, compiler/analyzer version, generated ignored
   diagnostic-log path, and any unexecuted Sandbox test.
5. Inspect the full Git diff and confirm no `.app`, `.alpackages`, `.build`,
   snapshot, launch, RAD, credential, backup AL, or third-party source is staged.
6. Update behavior, dependency, acceptance, transfer-audit, and installation
   documentation when affected.

Never report an AL task complete without this evidence.
