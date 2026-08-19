# Microsoft AL quality gates

Use these primary sources when the distribution model, analyzer configuration,
or validation requirements are in scope:

- Code analysis and analyzer setup:
  https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/devenv-using-code-analysis-tool
- CodeCop rules and default severities:
  https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/analyzers/codecop
- UICop rules:
  https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/analyzers/uicop
- PerTenantExtensionCop rules:
  https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/analyzers/pertenantextensioncop
- Technical validation checklist for Marketplace/AppSource:
  https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/devenv-checklist-submission
- AppSourceCop configuration and rules:
  https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/analyzers/appsourcecop
- Ruleset syntax:
  https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/devenv-rule-set-syntax-for-code-analysis-tools
- Symbol download:
  https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/al-agent-tools/al-tool-download-symbols

## Distribution decision

Use CodeCop and UICop for every app. Then select exactly one distribution
analyzer:

- private extension installed for a specific customer: PerTenantExtensionCop;
- public Marketplace/AppSource extension: AppSourceCop.

Do not enable both distribution analyzers. A Marketplace migration also needs
registered object ranges and affixes, supported countries, an AppSourceCop
compatibility baseline, signing, upgrade validation, and the complete Technical
Validation Checklist. Do not infer those values for a PTE.
