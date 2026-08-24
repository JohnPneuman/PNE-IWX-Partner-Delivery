# Analyzer baseline

## Current enforced baseline — 2026-08-24

The repository now has one reproducible PTE validation command for all three apps.
The 2026-08-24 setup check completed with 0 failures and 0 warnings. The
final validation ran AL compiler **17.0.34.45391** through AL Language
extension **17.0.2273547**, with CodeCop, UICop, and
PerTenantExtensionCop, applies the app rulesets, and treats every Warning as an
Error.

The exact Sandbox symbol set was Microsoft Application
28.4.53241.53312, Base Application 28.4.53241.53758, System Application
and Business Foundation 28.4.53241.53312, System 28.0.53445.0, Insight Works
Product Configurator 4.1.9649.1 and BluAce Pneuman 1.0.202608.1. Obsolete
28.3 and BluAce symbol packages were removed before the final run.

The original local AA0072 analyzer run reported 34 invalid object/type suffixes
in Frame Specification and 67 in Product Configurator Enhancements. The
pre-fix diagnostics JSON was not retained, so these are historical run counts
and cannot be reconstructed exactly from the Git diff alone. The findings were
corrected by behavior-neutral local variable and parameter renames. The
dependency-owned event subscriber parameter `RecRef` retains its published
name because changing it breaks event binding; the subscriber signature
remains unchanged.

An explicitly approved namespace migration then moved every object to
`Pneuman.FrameSpecification` or `Pneuman.ProductConfigurator`. Microsoft
`using` directives were resolved against the exact Business Central 28.4
symbols. AA0247 is now an Error rather than accepted baseline debt.

| App | Compiler/analyzer errors | Warnings | Info |
|---|---:|---:|---:|
| PNE Frame Specification 1.0.0.9 | 0 | 0 | 0 |
| PNE Product Configurator Enhancements 1.0.0.10 | 0 | 0 | 0 |
| PNE Production Order Reconciliation 2.8.0.1 | 0 | 0 | 0 |

The ignored evidence is written to each app's
`.build/validation-diagnostics.json`. Namespace consumer and Sandbox upgrade
risks are recorded in `namespace-compatibility-audit.md`.

The final 2.8.0.1 run compiled all three current apps and reported zero errors,
zero warnings and zero informational diagnostics for each. The Reconciliation
app-specific migration and Sandbox risks are recorded in
`production-order-reconciliation.md` and its manual acceptance matrix in
`production-order-reconciliation-test-plan.md`.

### Historical Reconciliation v1.1.0.3 result — superseded

The former 1.1.0.3 assembly-recipe/carrier-quantity implementation was
validated on 2026-08-20 with zero errors and warnings, and one informational
AA0232 on its `Used Cost Sum` FlowField. That app schema and source were
replaced by the clean 2.0.0.0 rebuild after the old Sandbox app was removed.
AA0232 is therefore **not** current baseline debt and must not be treated as a
warning or known diagnostic for v2.8.0.1.

## Historical analyzer details (pre-2026-08-20)

**Verified with the AL 17 compiler and analyzers.**

The migrated source was built on 2026-07-23 with AL Language extension
17.0.2273547 and compiler 17.0.34.45391. The initial analyzer-enabled build
succeeded and established these diagnostics:

| Category | Rule ID | Count | Files | Explanation | Resolution | Disposition |
|---|---|---:|---|---|---|---|
| Compiler | — | 0 | — | No compiler errors | None | Clean |
| CodeCop | AA0021 | 1 | `PNEIWXEventSubscribers.Codeunit.al` | Record variable followed a Page variable | Order Records before Pages | Fixed immediately; promoted to Error |
| CodeCop | AA0215 | 1 | `PNEIWXAdditionalChoicesType.EnumExt.al` | File name did not match the AL object name | Rename to `PNEIWXAddChoiceType.EnumExt.al` | Fixed immediately |
| CodeCop | AA0247 | 2 | Both AL source files | The app does not use namespaces | Consider namespaces only as a separately scoped compatibility change | Accepted baseline Info |
| UICop | — | 0 | — | No diagnostics reported | None | Clean |
| PerTenantExtensionCop | — | 0 | — | No diagnostics reported | None | Clean |

## Historical verified baseline after the initial namespace migration

After the behavior-neutral declaration reorder, file rename, and AA0021 Error
promotion, the full analyzer-enabled build completed successfully:

| Category | Errors | Warnings | Info |
|---|---:|---:|---:|
| Compiler | 0 | 0 | 0 |
| CodeCop | 0 | 0 | 5 × AA0247 |
| UICop | 0 | 0 | 0 |
| PerTenantExtensionCop | 0 | 0 | 0 |

The build created the package locally. The generated `.app` remains ignored.
The count of AA0247 informational diagnostics increased from two to five
because the behavior-neutral architecture extraction introduced three real AL
codeunits. Each of the five objects reports the same documented namespace
advisory; there are no new warning- or error-level diagnostics.

## Remaining review debt

- Existing dependency-style parameter names are difficult to read.
- Automated AL regression tests are not yet available.

At that historical point AA0247 remained informational. The current
2026-08-21 three-app validation above is authoritative and reports no
informational diagnostics. Namespaces are still changed only through focused,
compatibility-reviewed work.

## Option Choice profit-group feature verification

The feature branch was compiled on 2026-07-23 against Insight Works Product
Configurator 4.1.9649.1 and Blue Ace Pneuman 1.0.202606.5 with AL Language
17.0.2273547 and compiler 17.0.34.45391.

The first build reported three AA0470 warnings for missing placeholder comments
on new Labels. The Labels were given explicit placeholder comments and the full
build was repeated successfully:

| Category | Errors | Warnings | Info |
|---|---:|---:|---:|
| Compiler | 0 | 0 | 0 |
| CodeCop | 0 | 0 | 13 × AA0247 |
| UICop | 0 | 0 | 0 |
| PerTenantExtensionCop | 0 | 0 | 0 |

The eight additional AA0247 informational diagnostics correspond to eight new
AL objects. Namespaces remain a separately scoped compatibility change. No new
warning- or error-level diagnostic remains.

## Cleanup policy

1. Run compiler, CodeCop, UICop, and PerTenantExtensionCop together.
2. Record each new diagnostic ID, count, affected files, explanation,
   recommended fix, and immediate/tracked decision.
3. Fix trivial behavior-neutral findings first.
4. Address architectural findings through focused changes with regression
   tests; never hide them with blanket suppressions.

Existing documented warnings may temporarily remain. New changes must not
increase warning counts, and new or modified files must meet the agreed rules.
The baseline should decrease over time and may increase only with explicit,
documented approval.

## Configured Sales Line extended-text feature

The complete feature branch was rebuilt on 2026-08-11 against Insight Works
Product Configurator 4.1.9649.1 and Blue Ace Pneuman 1.0.202606.5 with AL
Language 17.0.2273547 and compiler 17.0.34.45391. CodeCop, UICop, and
PerTenantExtensionCop were enabled together with the repository ruleset.

| Category | Errors | Warnings | Info |
|---|---:|---:|---:|
| Compiler | 0 | 0 | 0 |
| CodeCop | 0 | 0 | 16 × AA0247 |
| UICop | 0 | 0 | 0 |
| PerTenantExtensionCop | 0 | 0 | 0 |

The three informational diagnostics added after the profit-group baseline
belong to enum extension 50113 and codeunits 50114 and 50115. They are the same
documented namespace advisory as the other objects. The build package was
written to a temporary audit directory and removed after verification; no
generated package was added to the repository.

## Frame Specification feature verification

The Frame Specification app was built on 2026-08-19 against Insight Works
Product Configurator 4.1.9649.1 with AL Language 17.0.2273547 and compiler
17.0.34.45391. CodeCop, UICop, and PerTenantExtensionCop were enabled together
with the app ruleset.

| Category | Errors | Warnings | Info |
|---|---:|---:|---:|
| Compiler | 0 | 0 | 0 |
| CodeCop | 0 | 0 | 12 × AA0247 |
| UICop | 0 | 0 | 0 |
| PerTenantExtensionCop | 0 | 0 | 0 |

Each information diagnostic is the existing namespace advisory. No
warning- or error-level diagnostic remains. The generated package was written
to a temporary audit directory and removed after verification.

## Configured Item Template default verification

The Item Disc. Group Choice Code placeholder feature, including its
pre-validation correction, was built on 2026-08-19 against Insight Works
Product Configurator 4.1.9649.1 and Blue Ace Pneuman 1.0.202606.5 with AL
Language 17.0.2273547 and compiler 17.0.34.45391.

| Category | Errors | Warnings | Info |
|---|---:|---:|---:|
| Compiler | 0 | 0 | 0 |
| CodeCop | 0 | 0 | 17 × AA0247 |
| UICop | 0 | 0 | 0 |
| PerTenantExtensionCop | 0 | 0 | 0 |

The additional information diagnostic belongs to codeunit 50116 and is the
same documented namespace advisory. No warning- or error-level diagnostic
remains.
