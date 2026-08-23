namespace Pneuman.ProductionOrderReconciliation;

table 50173 "PNE PIL Line"
{
    Caption = 'Imported PIL Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Header Entry No."; Integer) { Caption = 'Header Entry No.'; DataClassification = CustomerContent; TableRelation = "PNE PIL Header"."Entry No."; }
        field(2; "Line No."; Integer) { Caption = 'Line No.'; DataClassification = CustomerContent; }
        field(3; "Item No."; Code[20]) { Caption = 'AutoCAD Item No.'; DataClassification = CustomerContent; }
        field(4; Description; Text[100]) { Caption = 'Description'; DataClassification = CustomerContent; }
        field(5; Quantity; Decimal) { Caption = 'PIL Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(6; "Group Code"; Code[20]) { Caption = 'PIL Group Code'; DataClassification = CustomerContent; }
        field(7; "Covered By Item No."; Code[20]) { Caption = 'Covered by Driver Item No.'; DataClassification = CustomerContent; Editable = false; }
        field(8; "Resolution"; Text[100]) { Caption = 'Resolution'; DataClassification = CustomerContent; Editable = false; }
        field(9; "Covered Quantity"; Decimal) { Caption = 'Covered by Structural Carrier'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(10; "Ignore for Reconciliation"; Boolean) { Caption = 'Ignore for Reconciliation'; DataClassification = CustomerContent; Editable = false; }
        field(11; "Ignore Reason"; Text[250]) { Caption = 'Ignore Reason'; DataClassification = CustomerContent; Editable = false; }
        field(12; "Ignored By"; Text[50]) { Caption = 'Ignored By'; DataClassification = EndUserIdentifiableInformation; Editable = false; }
        field(13; "Ignored At"; DateTime) { Caption = 'Ignored At'; DataClassification = SystemMetadata; Editable = false; }
    }

    keys
    {
        key(PK; "Header Entry No.", "Line No.") { Clustered = true; }
        key(Item; "Header Entry No.", "Item No.") { }
        key(Group; "Header Entry No.", "Group Code") { }
    }

    trigger OnInsert()
    begin
        VerifyIgnoreAudit();
    end;

    trigger OnModify()
    var
        PNEPILHeader: Record "PNE PIL Header";
    begin
        PNEPILHeader.Get("Header Entry No.");
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AppliedLineChangeErr);
        VerifyIgnoreAudit();
    end;

    trigger OnDelete()
    var
        PNEPILHeader: Record "PNE PIL Header";
    begin
        PNEPILHeader.Get("Header Entry No.");
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AppliedLineDeleteErr);
    end;

    local procedure VerifyIgnoreAudit()
    begin
        if not "Ignore for Reconciliation" then
            exit;

        if DelChr("Ignore Reason", '<>', ' ') = '' then
            Error(IgnoreReasonRequiredErr);
        TestField("Ignored By");
        TestField("Ignored At");
    end;

    var
        AppliedLineChangeErr: Label 'Geïmporteerde regels van een toegepast PIL-dossier kunnen niet worden gewijzigd.';
        AppliedLineDeleteErr: Label 'Geïmporteerde regels van een toegepast PIL-dossier kunnen niet worden verwijderd.';
        IgnoreReasonRequiredErr: Label 'Bewust negeren vereist altijd een ingevulde reden.';
}
