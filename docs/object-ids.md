# Object IDs

PNE Product Configurator Enhancements range: **50100–50149**.

| Type | ID | Name | App/module | Purpose | Status |
|---|---:|---|---|---|---|
| Enum extension | 50100 | PNE IWX Add. Choice Type | Configurator Enhancements | Adds `Production BOMs` Additional Choices type | Existing |
| Codeunit | 50101 | PNE IWX Event Subscribers | Configurator Enhancements | Thin IWX event subscriber entry points | Existing |
| Codeunit | 50102 | PNE IWX Add. Choices Mgt. | Configurator Enhancements | Production BOM filter and selection orchestration | Assigned |
| Codeunit | 50103 | PNE IWX Adapter | Configurator Enhancements | IWX record access, validation, and current-session mapping | Assigned |
| Codeunit | 50104 | PNE Production BOM Cost Mgt. | Configurator Enhancements | Recursive missing Non-Inventory Production BOM costing | Assigned |
| Table extension | 50105 | PNE IWX Option Choice | Configurator Enhancements | Persistent Option Choice profit-group override | Assigned |
| Table extension | 50106 | PNE IWX Configurator BOM | Configurator Enhancements | Effective configurator-session profit group | Assigned |
| Page extension | 50107 | PNE IWX Option Choice Card | Configurator Enhancements | Profit group on the Option Choice card | Assigned |
| Page extension | 50108 | PNE IWX Option Choices | Configurator Enhancements | Profit group on the Option Choice list | Assigned |
| Page extension | 50109 | PNE IWX BOM Designer | Configurator Enhancements | Configurator-line profit-group override | Assigned |
| Codeunit | 50110 | PNE IWX Pricing Mgt. | Configurator Enhancements | Profit-group resolution and Unit Price calculation | Assigned |
| Page extension | 50111 | PNE IWX Config. Option SF | Configurator Enhancements | Profit group on the Configurator Option Choices subform | Assigned |
| Permission set extension | 50112 | PNE IWX PC User | Configurator Enhancements | Execute permission for pricing through the existing IWX user role | Assigned |
| Enum extension | 50113 | PNE IWX Smart Item No. Type | Configurator Enhancements | Adds the `Option Text` Smart Item Number component type | Assigned |
| Codeunit | 50114 | PNE Smart Item No. Mgt. | Configurator Enhancements | Resolves Smart Item Number Option Text from the configurator buffer | Assigned |
| Codeunit | 50115 | PNE IWX Extended Text Mgt. | Configurator Enhancements | Builds ordered configured Sales Line extended text | Assigned |
| Codeunit | 50116 | PNE IWX Item Template Mgt. | Configurator Enhancements | Applies opt-in Item Disc. Group Choice Code template defaults | Assigned |
| Codeunit | 50117 | PNE IWX Routing Complete Mgt. | Configurator Enhancements | Adds missing optional routing-link operations with zero time after IWX item configuration | Assigned |
| Page extension | 50118 | PNE Item Card Routing Repair | Configurator Enhancements | Explicit authorized repair action for missing optional Item-routing operations | Assigned |

IDs 50119–50149 are unassigned. Documentation of a possible future object does
not reserve or allocate an ID. Scan all AL source and update this file before
creating an object; existing IDs are not renumbered for cosmetic reasons.

PNE Frame Specification range: **50150–50169**.

| Type | ID | Name | App/module | Purpose | Status |
|---|---:|---|---|---|---|
| Enum | 50150 | PNE Frame Spec. Line Type | Frame Specification | Calculated line classification | Assigned |
| Table | 50151 | PNE Frame Spec. Rule | Frame Specification | Persisted Pneuman frame-report rules | Assigned |
| Table | 50152 | PNE Frame Spec. Line | Frame Specification | Temporary report and preview line type | Assigned |
| Page | 50153 | PNE Frame Spec. Rules | Frame Specification | Rule maintenance | Assigned |
| Codeunit | 50154 | PNE Frame Spec. Mgt. | Frame Specification | Configuration lookup and report-line calculation | Assigned |
| Permission set | 50155 | PNE Frame Spec. | Frame Specification | Rule maintenance and report execution | Assigned |
| Page | 50156 | PNE Frame Spec. Preview | Frame Specification | Temporary calculated preview | Assigned |
| Page | 50157 | PNE Frame Spec. Test | Frame Specification | Temporary calculation preview | Assigned |
| Report | 50158 | PNE Frame Specification | Frame Specification | Word-based production frame specification | Assigned |
| Page extension | 50159 | PNE Released Prod. Order | Frame Specification | Adds report action to Released Production Order | Assigned |
| Enum | 50160 | PNE Frame Spec. Component Type | Frame Specification | Rule component selection type | Assigned |
| Page | 50161 | PNE Frame BOM Components | Frame Specification | Production BOM component lookup | Assigned |
| Codeunit | 50162 | PNE Frame Spec. Action Mgt. | Frame Specification | Opens the report from a production order | Assigned |
| Page extension | 50163 | PNE Simulated Prod. Order | Frame Specification | Adds Frame Specification on Simulated Production Order | Assigned |
| Page extension | 50164 | PNE Firm Planned Prod. Order | Frame Specification | Adds Frame Specification on Firm Planned Prod. Order | Assigned |
| Permission set | 50165 | PNE Frame Spec. View | Frame Specification | Read-only production-order Frame Specification role | Assigned |

IDs 50166–50169 are unassigned.

PNE Production Order Reconciliation range: **50170–50201**.

| Type | ID | Name | App/module | Purpose | Status |
|---|---:|---|---|---|---|
| Table | 50170 | PNE PIL Group | Production Reconciliation | Group, CALC placeholder and cost audit setup | Assigned |
| Table | 50171 | PNE PIL Group Item | Production Reconciliation | Eligible real AutoCAD Inventory-items per group | Assigned |
| Table | 50172 | PNE PIL Header | Production Reconciliation | One import/audit dossier per production order | Assigned |
| Table | 50173 | PNE PIL Line | Production Reconciliation | Aggregated PIL item, group/resolution and mandatory-reason deliberate-ignore audit | Assigned |
| Table | 50174 | PNE PIL Target | Production Reconciliation | Resolved carrier/CALC identity snapshot, analysis source, proposed quantity and allocation | Assigned |
| Enum | 50175 | PNE PIL Status | Production Reconciliation | Imported/allocation-required/prepared/applied lifecycle | Assigned |
| Enum | 50176 | PNE PIL Target Kind | Production Reconciliation | Structural driver, CALC replacement, loose component or new point-carrier addition | Assigned |
| Codeunit | 50177 | PNE PIL Import | Production Reconciliation | Headerless AutoCAD import and raw/aggregate audit | Assigned |
| Codeunit | 50178 | PNE PIL Mgt. | Production Reconciliation | Structure analysis, allocation, live-safe apply, CALC replacement and standard routing recalculation | Assigned |
| Enum | 50179 | PNE PIL Carrier Type | Production Reconciliation | Production order line versus component carrier identity | Assigned |
| Page | 50180 | PNE PIL Groups | Production Reconciliation | PIL Setup and CALC cost action | Assigned |
| Page | 50181 | PNE PIL Group Items | Production Reconciliation | Eligible real AutoCAD articles | Assigned |
| Page | 50182 | PNE PIL Reconciliations | Production Reconciliation | Import history per production order | Assigned |
| Page | 50183 | PNE PIL Reconciliation | Production Reconciliation | Guided four-step prepare, allocate, review and apply card | Assigned |
| Page | 50184 | PNE PIL Lines Part | Production Reconciliation | Aggregated AutoCAD PIL review and deliberate-ignore audit part | Assigned |
| Page | 50185 | PNE PIL Targets Part | Production Reconciliation | Carrier allocation/review part | Assigned |
| Page | 50186 | PNE PIL Raw Lines Part | Production Reconciliation | Original AutoCAD source-row part | Assigned |
| Permission set | 50187 | PNE PIL Reconcile | Production Reconciliation | Daily PIL processing, audit/report and read-only production access; normal Sales Quote rights and setup maintenance remain separate | Assigned |
| Page extension | 50188 | PNE Simulated Prod. Order PIL | Production Reconciliation | PIL actions on Simulated Production Order | Assigned |
| Page extension | 50189 | PNE Firm Planned PIL | Production Reconciliation | PIL actions on Firm Planned Prod. Order | Assigned |
| Table | 50190 | PNE PIL Raw Line | Production Reconciliation | Original four-field AutoCAD audit row | Assigned |
| Page extension | 50191 | PNE Released Prod. Order PIL | Production Reconciliation | PIL actions on Released Production Order | Assigned |
| Codeunit | 50192 | PNE PIL Cost Mgt. | Production Reconciliation | Average real-item cost to CALC placeholder | Assigned |
| Enum | 50193 | PNE PIL Analysis Source | Production Reconciliation | Live production-order versus read-only master-BOM analysis provenance | Assigned |
| Table | 50194 | PNE PIL Change Line | Production Reconciliation | Per-carrier technical/commercial proposal, cost indication and sales-quote handoff/reversal/resolution link | Assigned |
| Page | 50195 | PNE PIL Change Lines Part | Production Reconciliation | Read-only proposal part on the reconciliation card | Assigned |
| Report | 50196 | PNE PIL Change Proposal | Production Reconciliation | Technical/commercial proposal with carrier decisions, quote-link review and reversal audit; raw AutoCAD rows remain hidden audit data | Assigned |
| Codeunit | 50197 | PNE PIL Sales Quote Mgt. | Production Reconciliation | Safe selected-quote handoff of grouped net morework/lesswork and pre-Apply reversal | Assigned |
| Table | 50198 | PNE PIL Quote Reversal | Production Reconciliation | Immutable audit of a safe pre-Apply sales-quote handoff reversal | Assigned |
| Page | 50198 | PNE PO Configuration Structure | Production Reconciliation | Only-lezen tijdelijke boom van de bestaande productieorder-BOM | Assigned |
| Permission set | 50198 | PNE PO Struct View | Production Reconciliation | Alleen bekijken van de configuratiestructuur en de benodigde standaard brondata | Assigned |
| Page | 50199 | PNE PIL Reason Dialog | Production Reconciliation | Mandatory-reason dialog for deliberate PIL exceptions and quote-handoff reversal | Assigned |
| Permission set | 50199 | PNE PIL Setup | Production Reconciliation | Separate PIL-group/article maintenance and CALC-cost role | Assigned |
| Codeunit | 50199 | PNE PO Config. Structure Mgt. | Production Reconciliation | Bouwt de tijdelijke, alleen-lezen configuratiestructuur uit de bestaande Production BOM | Assigned |
| Table | 50199 | PNE PIL Quote Resolution | Production Reconciliation | Immutable audit of a manually reviewed commercial-link release without Sales-document mutation | Assigned |
| Enum | 50199 | PNE PIL Quote Link State | Production Reconciliation | Observed current/missing/changed/unverifiable state of a released quote link | Assigned |
| Page | 50200 | PNE PIL Destination Lookup | Production Reconciliation | Keuze van een bestaande productieregel voor een bewust los toegevoegd AutoCAD-component | Assigned |
| Page | 50201 | PNE PIL Carrier Lookup | Production Reconciliation | Zoekt alle geschikte puntartikelen waarvan de gecertificeerde Production BOM het AutoCAD-artikel bevat | Assigned |

No numeric allocation remains free in the configured 50170..50201 range. Identieke nummers zijn
bewust toegestaan voor verschillende AL-objecttypen: 50198 wordt gebruikt door
een Table, Page en Permission set; 50199 door een Table, Enum, Page, Permission
set en Codeunit. Dit maakt geen tabel, veld of migratie dubbel.
