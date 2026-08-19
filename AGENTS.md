# Partner delivery agent instructions

Use `.agents/skills/business-central-al-quality/SKILL.md` for every AL change,
review, build, symbol, namespace, or development-environment task.

Before editing, read `docs/development-setup.md`, `docs/dependencies.md`,
`docs/current-behavior.md`, `docs/iwx-business-rules-compatibility.md`, the
relevant test plan, and `docs/namespace-compatibility-audit.md`. Inspect the
affected `app.json` and exact dependency symbols. Never invent an external
object, field, method, event, or signature.

These are private PTE apps. Always run CodeCop and UICop with
PerTenantExtensionCop; never enable AppSourceCop at the same time. Open
`PNE-IWX-Extensions.code-workspace`, run the setup check, format changed AL
files, and run the standard validation for both apps. Warnings are build
errors. Do not disable analyzers or add undocumented suppressions.

Preserve app IDs, object and field IDs, namespaces, public interfaces, event
signatures and `var` semantics, validation and database triggers, transaction
behavior, recursion/cycle guards, the IWX compatibility boundary, and documented
working behavior. A schema or public-symbol change requires a separate risk
report and explicit approval.

Use Sandbox only. Never store credentials or production configuration, use
ForceSync, delete extension data, add `Commit()`, publish, install, upgrade,
uninstall, sign, push, or deploy without explicit current permission. Never
commit `.app`, `.alpackages`, `.build`, snapshots, launch/RAD configuration,
credentials, or proprietary dependency source.

Do not report completion without setup, formatter, two-app validation, analyzer
diagnostics, full-diff inspection, and required Sandbox-test evidence.
