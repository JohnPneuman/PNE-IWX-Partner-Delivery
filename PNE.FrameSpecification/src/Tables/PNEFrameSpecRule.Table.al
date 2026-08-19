table 50151 "PNE Frame Spec. Rule"
{
    Caption = 'Frame Specification Rule';
    DataClassification = CustomerContent;
    DrillDownPageId = "PNE Frame Spec. Rules";
    LookupPageId = "PNE Frame Spec. Rules";

    fields
    {
        field(1; "Frame Configuration Code"; Code[20])
        {
            Caption = 'Item Category Code';
            DataClassification = CustomerContent;
            TableRelation = "IWX Cfg Item Category v3"."Item Category Code";
        }
        field(2; "Configuration Option"; Code[20])
        {
            Caption = 'Configuration Option';
            DataClassification = CustomerContent;
        }
        field(3; "Component Type"; Enum "PNE Frame Spec. Component Type")
        {
            Caption = 'Component Type';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if "Component Type" = "Component Type"::Item then
                    Clear("Production BOM No.");
                Clear("Component No.");
            end;
        }
        field(4; "Component No."; Code[20])
        {
            Caption = 'Component No.';
            DataClassification = CustomerContent;
            TableRelation = Item;

            trigger OnValidate()
            var
                Item: Record Item;
            begin
                if "Component No." = '' then begin
                    Clear(Description);
                    exit;
                end;
                if Item.Get("Component No.") then begin
                    Description := Item.Description;
                    if Quantity = 0 then
                        Quantity := 1;
                end;
            end;
        }
        field(5; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(6; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            InitValue = 1;
            MinValue = 0;
        }
        field(7; "Use Width"; Boolean)
        {
            Caption = 'Use Width';
            DataClassification = CustomerContent;
        }
        field(8; "Use Height"; Boolean)
        {
            Caption = 'Use Height';
            DataClassification = CustomerContent;
        }
        field(9; "Width Correction (mm)"; Decimal)
        {
            Caption = 'Width Correction (mm)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(10; "Height Correction (mm)"; Decimal)
        {
            Caption = 'Height Correction (mm)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(11; "Sort Order"; Integer)
        {
            Caption = 'Sort Order';
            DataClassification = CustomerContent;
        }
        field(12; Enabled; Boolean)
        {
            Caption = 'Enabled';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(13; "Production BOM No."; Code[20])
        {
            Caption = 'Production BOM No.';
            DataClassification = CustomerContent;
            TableRelation = "Production BOM Header";

            trigger OnValidate()
            begin
                Clear("Component No.");
            end;
        }
        field(14; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Frame Configuration Code", "Configuration Option", "Line No.")
        {
            Clustered = true;
        }
        key(SortOrder; "Frame Configuration Code", "Sort Order")
        {
        }
        key(LineNo; "Line No.")
        {
        }
    }

    trigger OnInsert()
    var
        FrameSpecRule: Record "PNE Frame Spec. Rule";
    begin
        FrameSpecRule.LockTable();
        FrameSpecRule.SetCurrentKey("Line No.");
        if FrameSpecRule.FindLast() then
            "Line No." := FrameSpecRule."Line No." + 10000
        else
            "Line No." := 10000;
    end;

}
