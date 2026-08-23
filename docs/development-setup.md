# AL development setup and validation

## Supported project layout

This repository contains three independent AL projects:

- `PNE.ProductConfiguratorEnhancements`;
- `PNE.FrameSpecification`; and
- `PNE.ProductionOrderReconciliation`.

Always open `PNE-IWX-Extensions.code-workspace`. It is a multi-root workspace
that loads all folders containing an `app.json`. Opening only the repository
root or one app can hide diagnostics from the other app.

## One-time workstation setup

1. Install a supported Visual Studio Code release.
2. Open `PNE-IWX-Extensions.code-workspace`.
3. Review the repository before granting Workspace Trust. Restricted Mode
   disables or limits workspace tasks, settings, debugging, and extensions.
4. Install the single recommended extension from Microsoft:
   `ms-dynamics-smb.al` (AL Language).
5. Run the workspace task `AL: Setup check`.

The setup check reports missing requirements and returns a failing exit code. It
does not install software, authenticate, download symbols, modify Business
Central, or store credentials.

## Analyzer configuration

Every app folder owns its settings and ruleset. They enable full-project
background analysis with:

- CodeCop for the official AL coding guidelines and general code quality;
- UICop for Business Central Web Client rules;
- PerTenantExtensionCop for private per-tenant extensions.

These apps are PTEs. AppSourceCop is not enabled and must not be combined with
PerTenantExtensionCop. A Marketplace migration is a separate distribution and
compatibility project.

The ruleset promotes the verified Microsoft declaration, naming, temporary
record, label, file/object naming, and namespace diagnostics. AA0021 means
variable declaration order by AL type; it does not require alphabetical
variable names. The standard command-line validation also treats every
remaining Warning as an Error.

## Download symbols safely

Symbols are local build dependencies. They belong in each app's ignored
`.alpackages` folder and must never be committed or placed in a delivery zip.

For each app separately:

1. Focus a file in that app folder in VS Code.
2. Try `AL: Download Symbols from Global Sources` for Microsoft and publicly
   available AppSource packages.
3. If an exact private dependency is unavailable globally, create a local
   `.vscode/launch.json` for an approved representative Sandbox and run
   `AL: Download Symbols`.
4. Authenticate interactively. Never write a password, token, client secret,
   or production tenant configuration into the repository.
5. Rerun `AL: Setup check` and confirm every dependency name and version from
   `app.json` is present.

Product Configurator Enhancements requires exact Insight Works Product
Configurator and Blue Ace Pneuman symbols. Frame Specification requires the
exact Insight Works symbols. After a dependency upgrade, inspect the actual
public symbols and event signatures before changing or compiling integration
code.

Production Order Reconciliation has no IWX or Blue Ace dependency and requires
only compatible Microsoft Business Central application symbols.

## Format and validate

Before reporting an AL task complete:

1. Run `Format Document` with the Microsoft AL formatter on every changed AL
   file.
2. Run the default build task `AL: Validate all PTE apps`, or execute:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-AlValidation.ps1
   ```

3. Inspect each app's ignored `.build/validation-diagnostics.json`.
4. Require zero compiler errors, zero CodeCop/UICop/PTECop warnings, and explain
   every remaining Info diagnostic.
5. Inspect the complete Git diff and staged-file list.
6. Run and record the relevant Sandbox scenarios. The validation task never
   publishes or installs an app.

The script locates the compiler and analyzer assemblies through the installed
official AL Language extension; it does not hard-code a developer name or AL
extension version. Generated packages and diagnostic logs remain under ignored
`.build` folders.

## Create a clean source delivery

Create a delivery only from a reviewed, committed Git state. From the
repository root, export tracked files with:

```powershell
git archive --format=zip --output PNE-IWX-Extensions-delivery.zip HEAD
```

This command exports committed `HEAD`; it does not include uncommitted work.
Never create the handover by zipping the working directory in File Explorer,
because ignored proprietary symbols and generated packages can still be
present on disk. Inspect the archive before transfer and confirm it contains no
`.git`, `.app`, `.alpackages`, `.build`, snapshots, `launch.json`, `rad.json`,
credentials, or internal use-case material.

## Troubleshooting

### Workspace tasks or analyzers do not run

- Confirm the `.code-workspace` file, rather than only a folder, is open.
- Check whether VS Code is in Restricted Mode.
- Confirm `ms-dynamics-smb.al` is installed and enabled for the workspace.
- Run `AL: Restart Language Server`, then rerun the setup check.

### Symbols are missing

- Run symbol download for the specific app whose editor tab is active.
- Confirm the target Sandbox contains the exact dependency versions in
  `app.json`.
- Refresh only the affected local symbol cache through the approved AL tooling;
  never substitute an arbitrary newer dependency.
- Do not copy proprietary symbols into Git or the partner delivery.

### The partner sees additional diagnostics

Capture the diagnostic code, analyzer/source, AL Language extension version,
file, and message from the Problems panel. Microsoft diagnostics are adopted by
code, not by an informal description such as "alphabetical variables". A
partner-specific rule must be documented separately from Microsoft CodeCop.

### A newer AL extension breaks validation

Record the compiler and analyzer versions and the new diagnostic codes. Fix
behavior-neutral issues directly; handle compatibility or architecture findings
in a focused change. Do not disable an analyzer or add a blanket suppression.
