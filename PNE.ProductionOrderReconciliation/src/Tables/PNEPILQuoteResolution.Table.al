namespace Pneuman.ProductionOrderReconciliation;

table 50199 "PNE PIL Quote Resolution"
{
    Caption = 'PIL Commercial Link Resolution';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; DataClassification = SystemMetadata; AutoIncrement = true; }
        field(2; "Header Entry No."; Integer) { Caption = 'Header Entry No.'; DataClassification = CustomerContent; TableRelation = "PNE PIL Header"."Entry No."; }
        field(3; "Change Line No."; Integer) { Caption = 'Change Line No.'; DataClassification = CustomerContent; }
        field(4; "Sales Quote No."; Code[20]) { Caption = 'Sales Quote No.'; DataClassification = CustomerContent; }
        field(5; "Sales Quote Line No."; Integer) { Caption = 'Sales Quote Line No.'; DataClassification = CustomerContent; }
        field(6; "Sales Quote Line SystemId"; Guid) { Caption = 'Sales Quote Line SystemId'; DataClassification = SystemMetadata; }
        field(7; "Sales Quote Line Modified At"; DateTime) { Caption = 'Sales Quote Line Modified At'; DataClassification = SystemMetadata; }
        field(8; "Carrier Item No."; Code[20]) { Caption = 'Carrier Item No.'; DataClassification = CustomerContent; }
        field(9; "Carrier Variant Code"; Code[10]) { Caption = 'Carrier Variant Code'; DataClassification = CustomerContent; }
        field(10; "Unit of Measure Code"; Code[10]) { Caption = 'Unit of Measure Code'; DataClassification = CustomerContent; }
        field(11; Quantity; Decimal) { Caption = 'Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(12; "Quote Line Description"; Text[100]) { Caption = 'Quote Line Description'; DataClassification = CustomerContent; }
        field(13; "Quote Unit Price"; Decimal) { Caption = 'Quote Unit Price'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(14; "Quote Line Amount"; Decimal) { Caption = 'Quote Line Amount'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(15; "Quote Currency Code"; Code[10]) { Caption = 'Quote Currency Code'; DataClassification = CustomerContent; }
        field(16; "Observed Link State"; Enum "PNE PIL Quote Link State") { Caption = 'Observed Link State'; DataClassification = CustomerContent; }
        field(17; "Resolution Reason"; Text[250]) { Caption = 'Resolution Reason'; DataClassification = CustomerContent; }
        field(18; "Resolved At"; DateTime) { Caption = 'Resolved At'; DataClassification = SystemMetadata; }
        field(19; "Resolved By"; Text[50]) { Caption = 'Resolved By'; DataClassification = EndUserIdentifiableInformation; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(HeaderChangeLine; "Header Entry No.", "Change Line No.") { }
        key(Quote; "Sales Quote No.", "Sales Quote Line No.") { }
    }

    trigger OnInsert()
    begin
        TestField("Header Entry No.");
        TestField("Change Line No.");
        TestField("Sales Quote No.");
        TestField("Sales Quote Line No.");
        TestField("Observed Link State");
        TestField("Resolution Reason");
        TestField("Resolved At");
        TestField("Resolved By");
    end;

    trigger OnModify()
    begin
        Error(QuoteResolutionImmutableErr);
    end;

    trigger OnDelete()
    begin
        Error(QuoteResolutionImmutableErr);
    end;

    var
        QuoteResolutionImmutableErr: Label 'Auditregels van een vrijgegeven PIL-offertekoppeling kunnen niet worden gewijzigd of verwijderd.';
}
