table 50152 "PNE Frame Spec. Line"
{
    Caption = 'Frame Specification Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Production Order No."; Code[20])
        {
            Caption = 'Production Order No.';
            DataClassification = CustomerContent;
        }
        field(2; "Production Order Line No."; Integer)
        {
            Caption = 'Production Order Line No.';
            DataClassification = CustomerContent;
        }
        field(3; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = CustomerContent;
        }
        field(4; "Source Configuration ID"; Code[20])
        {
            Caption = 'Source Configuration ID';
            DataClassification = CustomerContent;
        }
        field(5; "Frame Configuration Code"; Code[20])
        {
            Caption = 'Frame Configuration Code';
            DataClassification = CustomerContent;
        }
        field(6; "Configuration Option"; Code[20])
        {
            Caption = 'Configuration Option';
            DataClassification = CustomerContent;
        }
        field(7; "Line Type"; Enum "PNE Frame Spec. Line Type")
        {
            Caption = 'Line Type';
            DataClassification = CustomerContent;
        }
        field(8; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
        }
        field(9; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(10; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(11; "Width (mm)"; Decimal)
        {
            Caption = 'Width (mm)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(12; "Height (mm)"; Decimal)
        {
            Caption = 'Height (mm)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(13; "Width Correction (mm)"; Decimal)
        {
            Caption = 'Width Correction (mm)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(14; "Height Correction (mm)"; Decimal)
        {
            Caption = 'Height Correction (mm)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
    }

    keys
    {
        key(PK; "Production Order No.", "Production Order Line No.", "Line No.")
        {
            Clustered = true;
        }
        key(Description; Description, "Line No.")
        {
        }
    }
}
