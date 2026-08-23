namespace Pneuman.ProductionOrderReconciliation;

table 50190 "PNE PIL Raw Line"
{
    Caption = 'Imported AutoCAD PIL Raw Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Header Entry No."; Integer) { Caption = 'Header Entry No.'; DataClassification = CustomerContent; TableRelation = "PNE PIL Header"."Entry No."; }
        field(2; "Source Row No."; Integer) { Caption = 'Source Row No.'; DataClassification = CustomerContent; }
        field(3; "Item No."; Code[20]) { Caption = 'AutoCAD Item No.'; DataClassification = CustomerContent; }
        field(4; "Drawing Component No."; Code[50]) { Caption = 'Drawing Component No.'; DataClassification = CustomerContent; }
        field(5; "Terminal No."; Code[50]) { Caption = 'Terminal No.'; DataClassification = CustomerContent; }
        field(6; "Quantity Text"; Text[50]) { Caption = 'Art. Aantal (Raw)'; DataClassification = CustomerContent; }
        field(7; Quantity; Decimal) { Caption = 'Parsed Quantity'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(8; "Item Exists"; Boolean) { Caption = 'Item Exists in Business Central'; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Header Entry No.", "Source Row No.") { Clustered = true; }
    }

    trigger OnModify()
    begin
        Error(RawLineImmutableErr);
    end;

    trigger OnDelete()
    begin
        Error(RawLineImmutableErr);
    end;

    var
        RawLineImmutableErr: Label 'Originele AutoCAD-PIL-bronregels zijn auditregistraties en kunnen niet worden gewijzigd of verwijderd.';
}
