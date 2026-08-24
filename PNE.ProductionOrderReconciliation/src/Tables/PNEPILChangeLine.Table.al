namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Manufacturing.Document;

table 50194 "PNE PIL Change Line"
{
    Caption = 'PIL Change Proposal Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Header Entry No."; Integer) { Caption = 'Header Entry No.'; DataClassification = CustomerContent; TableRelation = "PNE PIL Header"."Entry No."; }
        field(2; "Line No."; Integer) { Caption = 'Line No.'; DataClassification = CustomerContent; }
        field(3; "Carrier Type"; Enum "PNE PIL Carrier Type") { Caption = 'Carrier Type'; DataClassification = CustomerContent; }
        field(4; "Carrier Status"; Enum "Production Order Status") { Caption = 'Carrier Status'; DataClassification = CustomerContent; }
        field(5; "Carrier Production Order No."; Code[20]) { Caption = 'Carrier Production Order No.'; DataClassification = CustomerContent; }
        field(6; "Carrier Order Line No."; Integer) { Caption = 'Carrier Production Order Line No.'; DataClassification = CustomerContent; }
        field(7; "Carrier Component Line No."; Integer) { Caption = 'Carrier Component Line No.'; DataClassification = CustomerContent; }
        field(8; "Carrier Item No."; Code[20]) { Caption = 'Carrier Item No.'; DataClassification = CustomerContent; }
        field(9; "Carrier Variant Code"; Code[10]) { Caption = 'Carrier Variant Code'; DataClassification = CustomerContent; }
        field(10; "Carrier Description"; Text[100]) { Caption = 'Carrier Description'; DataClassification = CustomerContent; }
        field(11; "Unit of Measure Code"; Code[10]) { Caption = 'Unit of Measure Code'; DataClassification = CustomerContent; }
        field(12; "Original Quantity"; Decimal) { Caption = 'Original Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(13; "Proposed Quantity"; Decimal) { Caption = 'Proposed Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(14; "Quantity Difference"; Decimal) { Caption = 'Quantity Difference'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(15; "Carrier Unit Cost"; Decimal) { Caption = 'Carrier Unit Cost'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(16; "Estimated Cost Difference"; Decimal) { Caption = 'Estimated Cost Difference'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(17; "PIL Details"; Text[250]) { Caption = 'PIL Details'; DataClassification = CustomerContent; }
        field(18; "Sales Quote No."; Code[20]) { Caption = 'Sales Quote No.'; DataClassification = CustomerContent; }
        field(19; "Sales Quote Line No."; Integer) { Caption = 'Sales Quote Line No.'; DataClassification = CustomerContent; }
        field(20; "Quote Unit Price"; Decimal) { Caption = 'Quote Unit Price'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(21; "Quote Line Amount"; Decimal) { Caption = 'Quote Line Amount'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(22; "Quote Currency Code"; Code[10]) { Caption = 'Quote Currency Code'; DataClassification = CustomerContent; }
        field(23; "Quote Added At"; DateTime) { Caption = 'Quote Added At'; DataClassification = SystemMetadata; }
        field(24; "Quote Added By"; Text[50]) { Caption = 'Quote Added By'; DataClassification = EndUserIdentifiableInformation; }
        field(25; "Quote Line Description"; Text[100]) { Caption = 'Quote Line Description'; DataClassification = CustomerContent; }
        field(26; "Quote Reversed"; Boolean) { Caption = 'Quote Reversed'; DataClassification = CustomerContent; }
        field(27; "Quote Reversal Entry No."; Integer) { Caption = 'Quote Reversal Entry No.'; DataClassification = CustomerContent; TableRelation = "PNE PIL Quote Reversal"."Entry No."; }
        field(28; "Sales Quote Line SystemId"; Guid) { Caption = 'Sales Quote Line SystemId'; DataClassification = SystemMetadata; }
        field(29; "Sales Quote Line Modified At"; DateTime) { Caption = 'Sales Quote Line Modified At'; DataClassification = SystemMetadata; }
        field(30; "Target Line No."; Integer) { Caption = 'PIL Target Line No.'; DataClassification = CustomerContent; Editable = false; }
        field(31; "Quote Link Released"; Boolean) { Caption = 'Quote Link Released'; DataClassification = CustomerContent; }
        field(32; "Quote Resolution Entry No."; Integer) { Caption = 'Quote Resolution Entry No.'; DataClassification = CustomerContent; TableRelation = "PNE PIL Quote Resolution"."Entry No."; }
    }

    keys
    {
        key(PK; "Header Entry No.", "Line No.") { Clustered = true; }
        key(Carrier; "Header Entry No.", "Carrier Type", "Carrier Status", "Carrier Production Order No.", "Carrier Order Line No.", "Carrier Component Line No.") { }
        key(Quote; "Sales Quote No.", "Sales Quote Line No.") { }
    }

    trigger OnModify()
    var
        PNEPILHeader: Record "PNE PIL Header";
    begin
        PNEPILHeader.Get("Header Entry No.");
        if IsControlledQuoteHandoffUpdate(xRec) then
            exit;
        if IsControlledQuoteReversalUpdate(xRec) then begin
            if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
                Error(AppliedChangeLineErr);
            exit;
        end;
        if IsControlledQuoteReleaseUpdate(xRec) then
            exit;
        Error(ChangeLineChangeErr);
    end;

    trigger OnDelete()
    var
        PNEPILHeader: Record "PNE PIL Header";
    begin
        PNEPILHeader.Get("Header Entry No.");
        if ("Sales Quote No." <> '') and not "Quote Reversed" then
            Error(TransferredChangeLineErr);
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AppliedChangeLineErr);
    end;

    local procedure IsControlledQuoteHandoffUpdate(OldPNEPILChangeLine: Record "PNE PIL Change Line"): Boolean
    begin
        if ("Sales Quote No." = '') or "Quote Reversed" or "Quote Link Released" or
           ("Quote Reversal Entry No." <> 0) or ("Quote Resolution Entry No." <> 0)
        then
            exit(false);
        if IsNullGuid("Sales Quote Line SystemId") or ("Sales Quote Line Modified At" = 0DT) then
            exit(false);
        if not HasSameTechnicalSnapshot(OldPNEPILChangeLine) then
            exit(false);
        if OldPNEPILChangeLine."Sales Quote No." = '' then
            exit(true);
        exit(OldPNEPILChangeLine."Quote Reversed");
    end;

    local procedure IsControlledQuoteReversalUpdate(OldPNEPILChangeLine: Record "PNE PIL Change Line"): Boolean
    var
        PNEPILQuoteReversal: Record "PNE PIL Quote Reversal";
    begin
        if (OldPNEPILChangeLine."Sales Quote No." = '') or OldPNEPILChangeLine."Quote Reversed" or OldPNEPILChangeLine."Quote Link Released" then
            exit(false);
        if not HasSameTechnicalSnapshot(OldPNEPILChangeLine) then
            exit(false);
        if ("Sales Quote No." <> OldPNEPILChangeLine."Sales Quote No.") or
           ("Sales Quote Line No." <> OldPNEPILChangeLine."Sales Quote Line No.") or
           ("Quote Unit Price" <> OldPNEPILChangeLine."Quote Unit Price") or
           ("Quote Line Amount" <> OldPNEPILChangeLine."Quote Line Amount") or
           ("Quote Currency Code" <> OldPNEPILChangeLine."Quote Currency Code") or
           ("Quote Added At" <> OldPNEPILChangeLine."Quote Added At") or
           ("Quote Added By" <> OldPNEPILChangeLine."Quote Added By") or
           ("Quote Line Description" <> OldPNEPILChangeLine."Quote Line Description") or
           ("Sales Quote Line SystemId" <> OldPNEPILChangeLine."Sales Quote Line SystemId") or
           ("Sales Quote Line Modified At" <> OldPNEPILChangeLine."Sales Quote Line Modified At") or
           "Quote Link Released" or
           ("Quote Resolution Entry No." <> 0) or
           not "Quote Reversed" or
           ("Quote Reversal Entry No." = 0)
        then
            exit(false);
        if not PNEPILQuoteReversal.Get("Quote Reversal Entry No.") then
            exit(false);
        exit(
            (PNEPILQuoteReversal."Header Entry No." = "Header Entry No.") and
            (PNEPILQuoteReversal."Change Line No." = "Line No.") and
            (PNEPILQuoteReversal."Sales Quote No." = "Sales Quote No.") and
            (PNEPILQuoteReversal."Sales Quote Line No." = "Sales Quote Line No.") and
            (PNEPILQuoteReversal."Sales Quote Line SystemId" = "Sales Quote Line SystemId") and
            (PNEPILQuoteReversal."Sales Quote Line Modified At" = "Sales Quote Line Modified At"));
    end;

    local procedure IsControlledQuoteReleaseUpdate(OldPNEPILChangeLine: Record "PNE PIL Change Line"): Boolean
    var
        PNEPILQuoteResolution: Record "PNE PIL Quote Resolution";
    begin
        if (OldPNEPILChangeLine."Sales Quote No." = '') or OldPNEPILChangeLine."Quote Reversed" or OldPNEPILChangeLine."Quote Link Released" then
            exit(false);
        if not HasSameTechnicalSnapshot(OldPNEPILChangeLine) then
            exit(false);
        if ("Sales Quote No." <> OldPNEPILChangeLine."Sales Quote No.") or
           ("Sales Quote Line No." <> OldPNEPILChangeLine."Sales Quote Line No.") or
           ("Quote Unit Price" <> OldPNEPILChangeLine."Quote Unit Price") or
           ("Quote Line Amount" <> OldPNEPILChangeLine."Quote Line Amount") or
           ("Quote Currency Code" <> OldPNEPILChangeLine."Quote Currency Code") or
           ("Quote Added At" <> OldPNEPILChangeLine."Quote Added At") or
           ("Quote Added By" <> OldPNEPILChangeLine."Quote Added By") or
           ("Quote Line Description" <> OldPNEPILChangeLine."Quote Line Description") or
           ("Sales Quote Line SystemId" <> OldPNEPILChangeLine."Sales Quote Line SystemId") or
           ("Sales Quote Line Modified At" <> OldPNEPILChangeLine."Sales Quote Line Modified At") or
           "Quote Reversed" or
           ("Quote Reversal Entry No." <> 0) or
           not "Quote Link Released" or
           ("Quote Resolution Entry No." = 0)
        then
            exit(false);
        if not PNEPILQuoteResolution.Get("Quote Resolution Entry No.") then
            exit(false);
        exit(
            (PNEPILQuoteResolution."Header Entry No." = "Header Entry No.") and
            (PNEPILQuoteResolution."Change Line No." = "Line No.") and
            (PNEPILQuoteResolution."Sales Quote No." = "Sales Quote No.") and
            (PNEPILQuoteResolution."Sales Quote Line No." = "Sales Quote Line No.") and
            (PNEPILQuoteResolution."Sales Quote Line SystemId" = "Sales Quote Line SystemId") and
            (PNEPILQuoteResolution."Sales Quote Line Modified At" = "Sales Quote Line Modified At"));
    end;

    local procedure HasSameTechnicalSnapshot(OldPNEPILChangeLine: Record "PNE PIL Change Line"): Boolean
    begin
        exit(
            ("Header Entry No." = OldPNEPILChangeLine."Header Entry No.") and
            ("Line No." = OldPNEPILChangeLine."Line No.") and
            ("Carrier Type" = OldPNEPILChangeLine."Carrier Type") and
            ("Carrier Status" = OldPNEPILChangeLine."Carrier Status") and
            ("Carrier Production Order No." = OldPNEPILChangeLine."Carrier Production Order No.") and
            ("Carrier Order Line No." = OldPNEPILChangeLine."Carrier Order Line No.") and
            ("Carrier Component Line No." = OldPNEPILChangeLine."Carrier Component Line No.") and
            ("Carrier Item No." = OldPNEPILChangeLine."Carrier Item No.") and
            ("Carrier Variant Code" = OldPNEPILChangeLine."Carrier Variant Code") and
            ("Carrier Description" = OldPNEPILChangeLine."Carrier Description") and
            ("Unit of Measure Code" = OldPNEPILChangeLine."Unit of Measure Code") and
            ("Original Quantity" = OldPNEPILChangeLine."Original Quantity") and
            ("Proposed Quantity" = OldPNEPILChangeLine."Proposed Quantity") and
            ("Quantity Difference" = OldPNEPILChangeLine."Quantity Difference") and
            ("Carrier Unit Cost" = OldPNEPILChangeLine."Carrier Unit Cost") and
            ("Estimated Cost Difference" = OldPNEPILChangeLine."Estimated Cost Difference") and
            ("PIL Details" = OldPNEPILChangeLine."PIL Details") and
            ("Target Line No." = OldPNEPILChangeLine."Target Line No."));
    end;

    var
        AppliedChangeLineErr: Label 'Voorstelregels van een toegepast PIL-dossier kunnen niet worden gewijzigd of verwijderd.';
        ChangeLineChangeErr: Label 'PIL-voorstelregels zijn auditregels. Gebruik de acties voor offerteoverdracht, terugdraaien of commerciële vrijgave; wijzig deze regels niet rechtstreeks.';
        TransferredChangeLineErr: Label 'Een voorstelregel die aan een offerte is toegevoegd, kan niet worden gewijzigd of verwijderd.';
}
