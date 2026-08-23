namespace Pneuman.ProductionOrderReconciliation;

table 50198 "PNE PIL Quote Reversal"
{
    Caption = 'PIL Sales Quote Reversal';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; DataClassification = SystemMetadata; AutoIncrement = true; }
        field(2; "Header Entry No."; Integer) { Caption = 'Header Entry No.'; DataClassification = CustomerContent; TableRelation = "PNE PIL Header"."Entry No."; }
        field(3; "Change Line No."; Integer) { Caption = 'Change Line No.'; DataClassification = CustomerContent; }
        field(4; "Sales Quote No."; Code[20]) { Caption = 'Sales Quote No.'; DataClassification = CustomerContent; }
        field(5; "Sales Quote Line No."; Integer) { Caption = 'Sales Quote Line No.'; DataClassification = CustomerContent; }
        field(6; "Carrier Item No."; Code[20]) { Caption = 'Carrier Item No.'; DataClassification = CustomerContent; }
        field(7; "Carrier Variant Code"; Code[10]) { Caption = 'Carrier Variant Code'; DataClassification = CustomerContent; }
        field(8; "Unit of Measure Code"; Code[10]) { Caption = 'Unit of Measure Code'; DataClassification = CustomerContent; }
        field(9; Quantity; Decimal) { Caption = 'Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(10; "Quote Line Description"; Text[100]) { Caption = 'Quote Line Description'; DataClassification = CustomerContent; }
        field(11; "Quote Unit Price"; Decimal) { Caption = 'Quote Unit Price'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(12; "Quote Line Amount"; Decimal) { Caption = 'Quote Line Amount'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(13; "Quote Currency Code"; Code[10]) { Caption = 'Quote Currency Code'; DataClassification = CustomerContent; }
        field(14; "Reversal Reason"; Text[250]) { Caption = 'Reversal Reason'; DataClassification = CustomerContent; }
        field(15; "Reversed At"; DateTime) { Caption = 'Reversed At'; DataClassification = SystemMetadata; }
        field(16; "Reversed By"; Text[50]) { Caption = 'Reversed By'; DataClassification = EndUserIdentifiableInformation; }
        field(17; "Sales Quote Line SystemId"; Guid) { Caption = 'Sales Quote Line SystemId'; DataClassification = SystemMetadata; }
        field(18; "Sales Quote Line Modified At"; DateTime) { Caption = 'Sales Quote Line Modified At'; DataClassification = SystemMetadata; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(HeaderChangeLine; "Header Entry No.", "Change Line No.") { }
        key(Quote; "Sales Quote No.", "Sales Quote Line No.") { }
    }

    trigger OnModify()
    begin
        Error(QuoteReversalImmutableErr);
    end;

    trigger OnDelete()
    begin
        Error(QuoteReversalImmutableErr);
    end;

    var
        QuoteReversalImmutableErr: Label 'Auditregels van een teruggedraaide PIL-offerteoverdracht kunnen niet worden gewijzigd of verwijderd.';
}
