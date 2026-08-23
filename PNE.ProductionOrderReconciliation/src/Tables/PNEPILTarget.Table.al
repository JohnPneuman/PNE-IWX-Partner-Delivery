namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;

table 50174 "PNE PIL Target"
{
    Caption = 'PIL Resolved Carrier';
    DataClassification = CustomerContent;
    Permissions = tabledata "PNE PIL Header" = m;

    fields
    {
        field(1; "Header Entry No."; Integer) { Caption = 'Header Entry No.'; DataClassification = CustomerContent; TableRelation = "PNE PIL Header"."Entry No."; }
        field(2; "Line No."; Integer) { Caption = 'Line No.'; DataClassification = CustomerContent; }
        field(3; "PIL Line No."; Integer) { Caption = 'PIL Line No.'; DataClassification = CustomerContent; }
        field(4; "PIL Item No."; Code[20]) { Caption = 'AutoCAD Item No.'; DataClassification = CustomerContent; }
        field(5; "PIL Item Description"; Text[100]) { Caption = 'AutoCAD Item Description'; DataClassification = CustomerContent; }
        field(6; "PIL Quantity"; Decimal) { Caption = 'PIL Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(7; "Allocated PIL Quantity"; Decimal)
        {
            Caption = 'To This Carrier';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;

            trigger OnValidate()
            var
                PNEPILChangeLine: Record "PNE PIL Change Line";
                PNEPILHeader: Record "PNE PIL Header";
                PNEPILTarget: Record "PNE PIL Target";
            begin
                PNEPILChangeLine.SetRange("Header Entry No.", "Header Entry No.");
                PNEPILChangeLine.SetFilter("Sales Quote No.", '<>%1', '');
                PNEPILChangeLine.SetRange("Quote Reversed", false);
                if not PNEPILChangeLine.IsEmpty() then
                    Error(QuotedProposalAllocationErr);
                PNEPILTarget.SetRange("Header Entry No.", "Header Entry No.");
                PNEPILTarget.SetRange("PIL Line No.", "PIL Line No.");
                PNEPILTarget.SetRange(Kind, Kind);
                if (Kind = Kind::"Structural driver") and (PNEPILTarget.Count() <= 1) then
                    Error(StructuralAllocationChangeErr);
                if Kind in [Kind::"Direct component addition", Kind::"Point carrier addition"] then
                    Error(DirectComponentAllocationChangeErr);

                if "Allocated PIL Quantity" <> xRec."Allocated PIL Quantity" then
                    ClearCarrierQuantityChoice();

                PNEPILHeader.Get("Header Entry No.");
                if ("Allocated PIL Quantity" <> xRec."Allocated PIL Quantity") and (PNEPILHeader.Status = PNEPILHeader.Status::Prepared) then begin
                    PNEPILHeader.Status := PNEPILHeader.Status::"Allocation Required";
                    Clear(PNEPILHeader."Prepared At");
                    PNEPILHeader.Modify(true);
                end;
            end;
        }
        field(8; "Unallocated PIL Quantity"; Decimal) { Caption = 'Still to Allocate'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(9; "Carrier Status"; Enum "Production Order Status") { Caption = 'Carrier Status'; DataClassification = CustomerContent; }
        field(10; "Carrier Production Order No."; Code[20]) { Caption = 'Carrier Production Order No.'; DataClassification = CustomerContent; }
        field(11; "Carrier Order Line No."; Integer) { Caption = 'Carrier Production Order Line No.'; DataClassification = CustomerContent; }
        field(12; "Carrier Item No."; Code[20]) { Caption = 'Carrier Item No.'; DataClassification = CustomerContent; }
        field(13; "Carrier Description"; Text[100]) { Caption = 'Carrier Description'; DataClassification = CustomerContent; }
        field(14; Kind; Enum "PNE PIL Target Kind") { Caption = 'Target Type'; DataClassification = CustomerContent; }
        field(15; "Quantity per Carrier"; Decimal) { Caption = 'Quantity per Carrier'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(16; "Original Carrier Quantity"; Decimal) { Caption = 'Original Carrier Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(17; "New Carrier Quantity"; Decimal) { Caption = 'New Carrier Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(18; "CALC Item No."; Code[20]) { Caption = 'CALC Item No.'; DataClassification = CustomerContent; }
        field(19; "PIL Group Code"; Code[20]) { Caption = 'PIL Group Code'; DataClassification = CustomerContent; }
        field(20; "Resolution"; Text[100]) { Caption = 'Allocation'; DataClassification = CustomerContent; Editable = false; }
        field(21; "Carrier Component Line No."; Integer) { Caption = 'Carrier Component Line No.'; DataClassification = CustomerContent; }
        field(22; "Carrier Type"; Enum "PNE PIL Carrier Type") { Caption = 'Carrier Type'; DataClassification = CustomerContent; }
        field(23; "Analysis Source"; Enum "PNE PIL Analysis Source") { Caption = 'Analysis Source'; DataClassification = CustomerContent; }
        field(24; "Carrier SystemId"; Guid) { Caption = 'Carrier SystemId'; DataClassification = SystemMetadata; Editable = false; }
        field(25; "Carrier Variant Code"; Code[10]) { Caption = 'Carrier Variant Code'; DataClassification = CustomerContent; Editable = false; }
        field(26; "Carrier Unit of Measure Code"; Code[10]) { Caption = 'Carrier Unit of Measure Code'; DataClassification = CustomerContent; Editable = false; }
        field(27; "Source CALC SystemId"; Guid) { Caption = 'Source CALC SystemId'; DataClassification = SystemMetadata; Editable = false; }
        field(28; "Source CALC Status"; Enum "Production Order Status") { Caption = 'Source CALC Status'; DataClassification = CustomerContent; Editable = false; }
        field(29; "CALC Source Prod. Order No."; Code[20]) { Caption = 'Source CALC Production Order No.'; DataClassification = CustomerContent; Editable = false; }
        field(30; "Source CALC Order Line No."; Integer) { Caption = 'Source CALC Production Order Line No.'; DataClassification = CustomerContent; Editable = false; }
        field(31; "Source CALC Component Line No."; Integer) { Caption = 'Source CALC Component Line No.'; DataClassification = CustomerContent; Editable = false; }
        field(32; "Source CALC Item No."; Code[20]) { Caption = 'Source CALC Item No.'; DataClassification = CustomerContent; Editable = false; }
        field(33; "Source CALC Variant Code"; Code[10]) { Caption = 'Source CALC Variant Code'; DataClassification = CustomerContent; Editable = false; }
        field(34; "CALC Source UOM Code"; Code[10]) { Caption = 'Source CALC Unit of Measure Code'; DataClassification = CustomerContent; Editable = false; }
        field(35; "Source CALC Expected Quantity"; Decimal) { Caption = 'Source CALC Expected Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(36; "Source CALC Quantity per"; Decimal) { Caption = 'Source CALC Quantity per'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(37; "Source CALC Qty. per UOM"; Decimal) { Caption = 'Source CALC Qty. per Unit of Measure'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(38; "New Point Carrier Item No."; Code[20]) { Caption = 'New Point Carrier Item No.'; DataClassification = CustomerContent; Editable = false; TableRelation = Item."No."; }
        field(39; "New Point Carrier Description"; Text[100]) { Caption = 'New Point Carrier Description'; DataClassification = CustomerContent; Editable = false; }
        field(40; "New Point Carrier SystemId"; Guid) { Caption = 'New Point Carrier SystemId'; DataClassification = SystemMetadata; Editable = false; }
        field(41; "New Point Carrier BOM No."; Code[20]) { Caption = 'New Point Carrier Production BOM No.'; DataClassification = CustomerContent; Editable = false; }
        field(42; "Destination Original Quantity"; Decimal) { Caption = 'Destination Original Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(43; "Driver Suggested Quantity"; Decimal) { Caption = 'Driver Suggested Carrier Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(44; "Carrier Quantity Conflict"; Boolean) { Caption = 'Carrier Quantity Conflict'; DataClassification = CustomerContent; Editable = false; }
        field(45; "Carrier Qty. Choice Active"; Boolean) { Caption = 'Carrier Quantity Choice Active'; DataClassification = CustomerContent; Editable = false; }
        field(46; "Chosen Carrier Quantity"; Decimal) { Caption = 'Chosen Carrier Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(47; "Carrier Qty. Choice Reason"; Text[250]) { Caption = 'Carrier Quantity Choice Reason'; DataClassification = CustomerContent; Editable = false; }
        field(48; "Carrier Qty. Chosen By"; Code[50]) { Caption = 'Carrier Quantity Chosen By'; DataClassification = EndUserIdentifiableInformation; Editable = false; }
        field(49; "Carrier Qty. Chosen At"; DateTime) { Caption = 'Carrier Quantity Chosen At'; DataClassification = CustomerContent; Editable = false; }
        field(50; "Observed Live Qty. per Carrier"; Decimal) { Caption = 'Observed Live Quantity per Carrier'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(51; "Factor Reconciliation Note"; Text[250]) { Caption = 'Factor Reconciliation Note'; DataClassification = CustomerContent; Editable = false; }
        field(52; "Existing Actual PIL Quantity"; Decimal) { Caption = 'Existing Actual PIL Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(53; "Existing Direct Comp. SystemId"; Guid) { Caption = 'Existing Direct Component SystemId'; DataClassification = SystemMetadata; Editable = false; }
        field(54; "Existing Direct Comp. Line No."; Integer) { Caption = 'Existing Direct Component Line No.'; DataClassification = CustomerContent; Editable = false; }
    }

    keys
    {
        key(PK; "Header Entry No.", "Line No.") { Clustered = true; }
        key(Carrier; "Header Entry No.", "Carrier Type", "Carrier Status", "Carrier Production Order No.", "Carrier Order Line No.", "Carrier Component Line No.") { }
    }

    trigger OnModify()
    var
        PNEPILHeader: Record "PNE PIL Header";
    begin
        PNEPILHeader.Get("Header Entry No.");
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AppliedTargetChangeErr);
    end;

    trigger OnDelete()
    var
        PNEPILHeader: Record "PNE PIL Header";
    begin
        PNEPILHeader.Get("Header Entry No.");
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AppliedTargetDeleteErr);
    end;

    local procedure ClearCarrierQuantityChoice()
    var
        OtherPNEPILTarget: Record "PNE PIL Target";
    begin
        if not (Kind in [Kind::"Structural driver", Kind::"CALC replacement"]) then
            exit;

        Clear("Carrier Qty. Choice Active");
        Clear("Chosen Carrier Quantity");
        Clear("Carrier Qty. Choice Reason");
        Clear("Carrier Qty. Chosen By");
        Clear("Carrier Qty. Chosen At");

        OtherPNEPILTarget.SetRange("Header Entry No.", "Header Entry No.");
        OtherPNEPILTarget.SetRange("Carrier Type", "Carrier Type");
        OtherPNEPILTarget.SetRange("Carrier Status", "Carrier Status");
        OtherPNEPILTarget.SetRange("Carrier Production Order No.", "Carrier Production Order No.");
        OtherPNEPILTarget.SetRange("Carrier Order Line No.", "Carrier Order Line No.");
        OtherPNEPILTarget.SetRange("Carrier Component Line No.", "Carrier Component Line No.");
        OtherPNEPILTarget.SetFilter("Line No.", '<>%1', "Line No.");
        if OtherPNEPILTarget.FindSet(true) then
            repeat
                if OtherPNEPILTarget."Carrier Qty. Choice Active" then begin
                    Clear(OtherPNEPILTarget."Carrier Qty. Choice Active");
                    Clear(OtherPNEPILTarget."Chosen Carrier Quantity");
                    Clear(OtherPNEPILTarget."Carrier Qty. Choice Reason");
                    Clear(OtherPNEPILTarget."Carrier Qty. Chosen By");
                    Clear(OtherPNEPILTarget."Carrier Qty. Chosen At");
                    OtherPNEPILTarget.Modify(true);
                end;
            until OtherPNEPILTarget.Next() = 0;
    end;

    var
        AppliedTargetChangeErr: Label 'De verdeling van een toegepast PIL-dossier kan niet meer worden gewijzigd.';
        AppliedTargetDeleteErr: Label 'Verdelingsregels van een toegepast PIL-dossier kunnen niet worden verwijderd.';
        QuotedProposalAllocationErr: Label 'Dit PIL-voorstel is al aan een offerte gekoppeld. Draai de offerteoverdracht eerst terug of importeer de PIL opnieuw voor een andere verdeling.';
        StructuralAllocationChangeErr: Label 'Een structurele driver wordt rechtstreeks uit het PIL-aantal berekend. Verdeel alleen regels waarvoor meerdere geldige carriers worden getoond.';
        DirectComponentAllocationChangeErr: Label 'Een rechtstreekse toevoeging of een nieuw puntartikel gebruikt altijd het volledige geïmporteerde PIL-aantal en kan niet handmatig worden verdeeld.';
}
