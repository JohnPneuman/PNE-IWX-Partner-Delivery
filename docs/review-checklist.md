# Review checklist

## Build and analysis

- [ ] The affected app compiles with the supported compiler and symbols.
- [ ] The setup check passed and all AL projects were included in validation.
- [ ] CodeCop, UICop, and PerTenantExtensionCop ran with warnings as errors.
- [ ] There are zero compiler/analyzer errors and warnings; every Info is
      reported and justified.
- [ ] No analyzer was disabled and every suppression is specific and justified.
- [ ] The AL Formatter ran on changed AL files.

## Source and architecture

- [ ] One object exists per correctly named file.
- [ ] Every object has the approved app namespace and ordered `using` directives.
- [ ] Object IDs are valid, unchanged where required, and documented.
- [ ] Event subscribers remain thin.
- [ ] Business logic resides in the appropriate management codeunit.
- [ ] Direct IWX mapping is isolated in the integration/adapter boundary.
- [ ] Calculations and business rules are not duplicated.
- [ ] Recursion has an explicit bound or circular-reference check.
- [ ] No new `Commit()` was introduced without a documented reason.

## Business Central behavior

- [ ] Insert/Modify/Delete and validation-trigger behavior is intentional.
- [ ] No trigger was accidentally bypassed.
- [ ] Created fields have correct `DataClassification`.
- [ ] Permissions were considered and permission sets exist for created data.
- [ ] Captions and user-facing messages use Labels where applicable.
- [ ] Database access in loops was reviewed.

## IWX and Production BOM invariants

- [ ] IWX dependency symbols and assumptions are documented.
- [ ] Production BOM choices remain permanent and type `Production BOM`.
- [ ] Inventory cost is not added twice.
- [ ] Only missing Non-Inventory cost is added to IWX Unit Cost.
- [ ] Nested BOM and circular-reference behavior remains intact.
- [ ] The current-session Choice Code workaround is preserved.
- [ ] Unit Cost remains immediately visible and Unit Price is unchanged unless
      explicitly in scope.
- [ ] Smart Item Number `Option Text` handles only its explicit type and leaves
      standard IWX component types and number composition unchanged.
- [ ] Smart Item Number lookup uses the supplied temporary configuration buffer
      and handles blank or missing Option values intentionally.
- [ ] Configured Sales Line text preserves Option display order, IWX formula
      context, nested quantities, duplicate prevention, and cycle detection.
- [ ] The documented Sales Quote, `NLD`, All Language Codes, WorkDate, wrapping,
      and group-separator scope matches the implementation.

## Tests, documentation, and repository hygiene

- [ ] Automated tests or relevant manual test-plan cases were completed.
- [ ] Architecture, dependencies, behavior, object IDs, and debt docs were
      updated when affected.
- [ ] No backup `.al`, `.app`, `.alpackages`, tenant launch data, credentials,
      or proprietary dependency source is staged.
- [ ] The final diff was read completely.
