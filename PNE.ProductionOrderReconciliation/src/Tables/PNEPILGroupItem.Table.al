namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Inventory.Item;

table 50171 "PNE PIL Group Item"
{
    Caption = 'PIL-groepartikel';
    DataClassification = CustomerContent;
    DrillDownPageId = "PNE PIL Group Items";
    LookupPageId = "PNE PIL Group Items";

    fields
    {
        field(1; "Group Code"; Code[20])
        {
            Caption = 'PIL-groepcode';
            DataClassification = CustomerContent;
            TableRelation = "PNE PIL Group".Code where(Enabled = const(true));

            trigger OnValidate()
            begin
                CheckUniqueEnabledItemMapping();
            end;
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Artikelnr.';
            DataClassification = CustomerContent;
            TableRelation = Item."No." where(Type = const(Inventory));

            trigger OnValidate()
            var
                Item: Record Item;
            begin
                if "Item No." = '' then begin
                    Clear(Description);
                    exit;
                end;

                Item.Get("Item No.");
                Description := Item.Description;
                CheckUniqueEnabledItemMapping();
            end;
        }
        field(3; Description; Text[100]) { Caption = 'Omschrijving'; DataClassification = CustomerContent; Editable = false; }
        field(4; Enabled; Boolean)
        {
            Caption = 'Actief';
            DataClassification = CustomerContent;
            InitValue = true;

            trigger OnValidate()
            begin
                CheckUniqueEnabledItemMapping();
            end;
        }
    }

    keys
    {
        key(PK; "Group Code", "Item No.") { Clustered = true; }
        key(Item; "Item No.", Enabled) { }
    }

    trigger OnInsert()
    begin
        CheckUniqueEnabledItemMapping();
    end;

    trigger OnModify()
    begin
        CheckUniqueEnabledItemMapping();
    end;

    trigger OnRename()
    begin
        CheckUniqueEnabledItemMapping();
    end;

    local procedure CheckUniqueEnabledItemMapping()
    var
        OtherPNEPILGroup: Record "PNE PIL Group";
        OtherPNEPILGroupItem: Record "PNE PIL Group Item";
        PNEPILGroup: Record "PNE PIL Group";
    begin
        if ("Group Code" = '') or ("Item No." = '') or not Enabled then
            exit;
        if not PNEPILGroup.Get("Group Code") or not PNEPILGroup.Enabled then
            exit;

        OtherPNEPILGroupItem.SetRange("Item No.", "Item No.");
        OtherPNEPILGroupItem.SetRange(Enabled, true);
        OtherPNEPILGroupItem.SetFilter("Group Code", '<>%1', "Group Code");
        if not OtherPNEPILGroupItem.FindSet() then
            exit;

        repeat
            if not IsCurrentMappingBeforeRename(OtherPNEPILGroupItem) and
               OtherPNEPILGroup.Get(OtherPNEPILGroupItem."Group Code") and OtherPNEPILGroup.Enabled
            then
                Error(
                    DuplicateEnabledItemMappingErr,
                    "Item No.",
                    OtherPNEPILGroupItem."Group Code");
        until OtherPNEPILGroupItem.Next() = 0;
    end;

    local procedure IsCurrentMappingBeforeRename(OtherPNEPILGroupItem: Record "PNE PIL Group Item"): Boolean
    begin
        exit(
            (OtherPNEPILGroupItem."Group Code" = xRec."Group Code") and
            (OtherPNEPILGroupItem."Item No." = xRec."Item No."));
    end;

    var
        DuplicateEnabledItemMappingErr: Label 'AutoCAD-artikel %1 is al een actief artikel van PIL-groep %2. Schakel de bestaande koppeling uit of gebruik één PIL-groep.', Comment = '%1 = AutoCAD item number, %2 = PIL group code';
}
