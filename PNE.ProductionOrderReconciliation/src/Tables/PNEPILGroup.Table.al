namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Inventory.Item;

table 50170 "PNE PIL Group"
{
    Caption = 'PIL-groep';
    DataClassification = CustomerContent;
    DrillDownPageId = "PNE PIL Groups";
    LookupPageId = "PNE PIL Groups";

    fields
    {
        field(1; Code; Code[20]) { Caption = 'Code'; DataClassification = CustomerContent; NotBlank = true; }
        field(2; Description; Text[100]) { Caption = 'Omschrijving'; DataClassification = CustomerContent; }
        field(3; "CALC Item No."; Code[20])
        {
            Caption = 'CALC-placeholderartikelnr.';
            DataClassification = CustomerContent;
            TableRelation = Item."No." where(Type = const("Non-Inventory"));

            trigger OnValidate()
            begin
                CheckUniqueEnabledCALCItem();
                CheckUniqueEnabledGroupItems();
            end;
        }
        field(4; Enabled; Boolean)
        {
            Caption = 'Actief';
            DataClassification = CustomerContent;
            InitValue = true;

            trigger OnValidate()
            begin
                CheckUniqueEnabledCALCItem();
                CheckUniqueEnabledGroupItems();
            end;
        }
        field(5; "Active Item Count"; Integer) { Caption = 'Aantal actieve artikelen'; DataClassification = CustomerContent; Editable = false; }
        field(6; "Used Cost Sum"; Decimal) { Caption = 'Som kostprijzen'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(7; "Average Unit Cost"; Decimal) { Caption = 'Gemiddelde kostprijs'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; Editable = false; }
        field(8; "Last Cost Recalculated At"; DateTime) { Caption = 'Kostprijs laatst herberekend op'; DataClassification = SystemMetadata; Editable = false; }
    }

    keys { key(PK; Code) { Clustered = true; } }

    trigger OnInsert()
    begin
        CheckUniqueEnabledCALCItem();
        CheckUniqueEnabledGroupItems();
    end;

    trigger OnModify()
    begin
        CheckUniqueEnabledCALCItem();
        CheckUniqueEnabledGroupItems();
    end;

    trigger OnRename()
    begin
        Error(GroupCodeRenameErr);
    end;

    trigger OnDelete()
    var
        PNEPILGroupItem: Record "PNE PIL Group Item";
    begin
        PNEPILGroupItem.SetRange("Group Code", Code);
        if not PNEPILGroupItem.IsEmpty() then
            Error(GroupHasItemsErr, Code);
    end;

    local procedure CheckUniqueEnabledCALCItem()
    var
        OtherPNEPILGroup: Record "PNE PIL Group";
    begin
        if not Enabled or ("CALC Item No." = '') then
            exit;

        OtherPNEPILGroup.SetRange(Enabled, true);
        OtherPNEPILGroup.SetRange("CALC Item No.", "CALC Item No.");
        OtherPNEPILGroup.SetFilter(Code, '<>%1', Code);
        if not OtherPNEPILGroup.IsEmpty() then
            Error(DuplicateCALCItemErr, "CALC Item No.");
    end;

    local procedure CheckUniqueEnabledGroupItems()
    var
        OtherPNEPILGroup: Record "PNE PIL Group";
        OtherPNEPILGroupItem: Record "PNE PIL Group Item";
        PNEPILGroupItem: Record "PNE PIL Group Item";
    begin
        if not Enabled then
            exit;

        PNEPILGroupItem.SetRange("Group Code", Code);
        PNEPILGroupItem.SetRange(Enabled, true);
        if not PNEPILGroupItem.FindSet() then
            exit;

        repeat
            OtherPNEPILGroupItem.SetRange("Item No.", PNEPILGroupItem."Item No.");
            OtherPNEPILGroupItem.SetRange(Enabled, true);
            OtherPNEPILGroupItem.SetFilter("Group Code", '<>%1', Code);
            if OtherPNEPILGroupItem.FindSet() then
                repeat
                    if OtherPNEPILGroup.Get(OtherPNEPILGroupItem."Group Code") then
                        if OtherPNEPILGroup.Enabled then
                            Error(
                                DuplicateEnabledGroupItemErr,
                                PNEPILGroupItem."Item No.",
                                OtherPNEPILGroupItem."Group Code");
                until OtherPNEPILGroupItem.Next() = 0;
        until PNEPILGroupItem.Next() = 0;
    end;

    var
        DuplicateCALCItemErr: Label 'CALC-placeholder %1 wordt al gebruikt door een andere actieve PIL-groep.', Comment = '%1 = CALC item number';
        DuplicateEnabledGroupItemErr: Label 'AutoCAD-artikel %1 is al een actief artikel van PIL-groep %2. Schakel de bestaande koppeling uit of gebruik één PIL-groep.', Comment = '%1 = AutoCAD item number, %2 = PIL group code';
        GroupCodeRenameErr: Label 'De code van een PIL-groep kan niet worden gewijzigd, omdat de code bestaande artikelkoppelingen en auditregels identificeert. Maak een nieuwe groep en schakel de oude groep uit.';
        GroupHasItemsErr: Label 'PIL-groep %1 bevat nog PIL-artikelen. Verwijder eerst die artikelkoppelingen of schakel de groep uit.', Comment = '%1 = PIL group code';
}
