namespace Pneuman.ProductConfigurator;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Routing;

codeunit 50117 "PNE IWX Routing Complete Mgt."
{
    Access = Internal;
    InherentPermissions = X;
    Permissions = tabledata "IWX Cfg Item Category v3" = r,
                  tabledata "IWX Configurator BOM v3" = r,
                  tabledata "Routing Header" = rm,
                  tabledata "Routing Line" = rim,
                  tabledata "Routing Version" = r;

    procedure EnsureOptionalRoutingLines(Item: Record Item; IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3")
    begin
        EnsureOptionalRoutingLinesForCategory(Item, IWXConfiguratorBOMv3."Item Category Code");
    end;

    procedure RepairOptionalRoutingLinesForExistingConfiguredItem(Item: Record Item): Integer
    var
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        ItemCategoryCode: Code[20];
        ConfigurationID: Code[20];
    begin
        if (Item."No." = '') or
           not Item."IWX Created from Configurator"
        then
            exit;

        Clear(ItemCategoryCode);
        Clear(ConfigurationID);
        IWXConfiguratorBOMv3.SetLoadFields(
            "Configured Item No.",
            "Configuration ID",
            "Item Category Code");
        IWXConfiguratorBOMv3.SetRange("Configured Item No.", Item."No.");
        IWXConfiguratorBOMv3.SetFilter("Configuration ID", '<>%1', '');
        if not IWXConfiguratorBOMv3.FindSet() then
            exit;

        repeat
            if ItemCategoryCode = '' then
                ItemCategoryCode := IWXConfiguratorBOMv3."Item Category Code"
            else
                if ItemCategoryCode <> IWXConfiguratorBOMv3."Item Category Code" then
                    Error(AmbiguousConfiguredItemErr, Item."No.");

            if ConfigurationID = '' then
                ConfigurationID := IWXConfiguratorBOMv3."Configuration ID"
            else
                if ConfigurationID <> IWXConfiguratorBOMv3."Configuration ID" then
                    Error(AmbiguousConfiguredItemErr, Item."No.");
        until IWXConfiguratorBOMv3.Next() = 0;

        exit(EnsureOptionalRoutingLinesForCategory(Item, ItemCategoryCode));
    end;

    local procedure EnsureOptionalRoutingLinesForCategory(Item: Record Item; ItemCategoryCode: Code[20]): Integer
    var
        IWXCfgItemCategoryv3: Record "IWX Cfg Item Category v3";
        ChoiceRoutingLine: Record "Routing Line";
        ExistingRoutingLine: Record "Routing Line";
        NewRoutingLine: Record "Routing Line";
        RoutingHeader: Record "Routing Header";
        TempMissingChoiceRoutingLine: Record "Routing Line" temporary;
        OriginalRoutingStatus: Enum "Routing Status";
        AddedLineCount: Integer;
        RoutingWasReopened: Boolean;
    begin
        if (Item."Routing No." = '') or (ItemCategoryCode = '') then
            exit;
        if not IWXCfgItemCategoryv3.Get(ItemCategoryCode) then
            exit;
        if IWXCfgItemCategoryv3."Choices Routing No." = '' then
            exit;

        EnsureRoutingHasNoVersions(Item."Routing No.");
        EnsureRoutingHasNoVersions(IWXCfgItemCategoryv3."Choices Routing No.");

        ChoiceRoutingLine.SetRange("Routing No.", IWXCfgItemCategoryv3."Choices Routing No.");
        ChoiceRoutingLine.SetRange("Version Code", '');
        ChoiceRoutingLine.SetFilter("Routing Link Code", '<>%1', '');
        if not ChoiceRoutingLine.FindSet() then
            exit;

        repeat
            ExistingRoutingLine.Reset();
            ExistingRoutingLine.SetRange("Routing No.", Item."Routing No.");
            ExistingRoutingLine.SetRange("Version Code", '');
            ExistingRoutingLine.SetRange("Routing Link Code", ChoiceRoutingLine."Routing Link Code");
            if ExistingRoutingLine.IsEmpty() then begin
                TempMissingChoiceRoutingLine := ChoiceRoutingLine;
                TempMissingChoiceRoutingLine.Insert();
            end;
        until ChoiceRoutingLine.Next() = 0;
        if TempMissingChoiceRoutingLine.IsEmpty() then
            exit;

        RoutingHeader.LockTable();
        RoutingHeader.Get(Item."Routing No.");
        OriginalRoutingStatus := RoutingHeader.Status;
        TempMissingChoiceRoutingLine.FindSet();
        repeat
            ExistingRoutingLine.Reset();
            ExistingRoutingLine.SetRange("Routing No.", Item."Routing No.");
            ExistingRoutingLine.SetRange("Version Code", '');
            ExistingRoutingLine.SetRange("Routing Link Code", TempMissingChoiceRoutingLine."Routing Link Code");
            if ExistingRoutingLine.IsEmpty() then begin
                if not RoutingWasReopened then begin
                    if RoutingHeader.Status = RoutingHeader.Status::Certified then begin
                        RoutingHeader.Validate(Status, RoutingHeader.Status::"Under Development");
                        RoutingHeader.Modify(true);
                    end else
                        if RoutingHeader.Status <> RoutingHeader.Status::"Under Development" then
                            Error(UnsupportedRoutingStatusErr, RoutingHeader."No.", RoutingHeader.Status);
                    RoutingWasReopened := true;
                end;

                if NewRoutingLine.Get(Item."Routing No.", '', TempMissingChoiceRoutingLine."Operation No.") then
                    Error(OperationConflictErr, TempMissingChoiceRoutingLine."Operation No.", Item."Routing No.");
                InitializeOptionalRoutingLine(
                    NewRoutingLine,
                    TempMissingChoiceRoutingLine,
                    Item."Routing No.");
                NewRoutingLine.Insert(true);
                AddedLineCount += 1;
            end;
        until TempMissingChoiceRoutingLine.Next() = 0;

        if RoutingWasReopened and (OriginalRoutingStatus = RoutingHeader.Status::Certified) then begin
            RoutingHeader.Validate(Status, RoutingHeader.Status::Certified);
            RoutingHeader.Modify(true);
        end;
        exit(AddedLineCount);
    end;

    local procedure EnsureRoutingHasNoVersions(RoutingNo: Code[20])
    var
        RoutingVersion: Record "Routing Version";
    begin
        RoutingVersion.SetRange("Routing No.", RoutingNo);
        if not RoutingVersion.IsEmpty() then
            Error(RoutingVersionUnsupportedErr, RoutingNo);
    end;

    local procedure InitializeOptionalRoutingLine(var NewRoutingLine: Record "Routing Line"; ChoiceRoutingLine: Record "Routing Line"; TargetRoutingNo: Code[20])
    begin
        NewRoutingLine.Init();
        NewRoutingLine."Routing No." := TargetRoutingNo;
        NewRoutingLine."Version Code" := '';
        NewRoutingLine."Operation No." := ChoiceRoutingLine."Operation No.";
        NewRoutingLine."Previous Operation No." := ChoiceRoutingLine."Previous Operation No.";
        NewRoutingLine."Next Operation No." := ChoiceRoutingLine."Next Operation No.";
        NewRoutingLine.Validate(Type, ChoiceRoutingLine.Type);
        NewRoutingLine.Validate("No.", ChoiceRoutingLine."No.");
        NewRoutingLine.Description := ChoiceRoutingLine.Description;
        NewRoutingLine."Description 2" := ChoiceRoutingLine."Description 2";
        NewRoutingLine."Routing Link Code" := ChoiceRoutingLine."Routing Link Code";
        NewRoutingLine."Standard Task Code" := ChoiceRoutingLine."Standard Task Code";
        NewRoutingLine."Setup Time" := 0;
        NewRoutingLine."Run Time" := 0;
        NewRoutingLine."Wait Time" := 0;
        NewRoutingLine."Move Time" := 0;
        NewRoutingLine."Fixed Scrap Quantity" := ChoiceRoutingLine."Fixed Scrap Quantity";
        NewRoutingLine."Lot Size" := ChoiceRoutingLine."Lot Size";
        NewRoutingLine."Scrap Factor %" := ChoiceRoutingLine."Scrap Factor %";
        NewRoutingLine."Setup Time Unit of Meas. Code" := ChoiceRoutingLine."Setup Time Unit of Meas. Code";
        NewRoutingLine."Run Time Unit of Meas. Code" := ChoiceRoutingLine."Run Time Unit of Meas. Code";
        NewRoutingLine."Wait Time Unit of Meas. Code" := ChoiceRoutingLine."Wait Time Unit of Meas. Code";
        NewRoutingLine."Move Time Unit of Meas. Code" := ChoiceRoutingLine."Move Time Unit of Meas. Code";
        NewRoutingLine."Concurrent Capacities" := ChoiceRoutingLine."Concurrent Capacities";
        NewRoutingLine."Send-Ahead Quantity" := ChoiceRoutingLine."Send-Ahead Quantity";
    end;

    var
        AmbiguousConfiguredItemErr: Label 'Artikel %1 is aan meerdere opgeslagen IWX-configuraties gekoppeld. De optionele routing kan niet automatisch worden hersteld.', Comment = '%1=item no.';
        OperationConflictErr: Label 'Bewerking %1 bestaat al in routing %2, maar heeft een andere routing-link. De optionele routing kan niet veilig worden aangevuld.', Comment = '%1=operation no.;%2=routing no.';
        RoutingVersionUnsupportedErr: Label 'Routing %1 bevat een of meer versies. De optionele routing kan niet veilig automatisch worden aangevuld, omdat alleen de basisrouting zou worden gewijzigd. Werk de gekozen routingversie handmatig bij of laat de inrichting eerst vereenvoudigen.', Comment = '%1=routing no.';
        UnsupportedRoutingStatusErr: Label 'Routing %1 heeft status %2. Ontbrekende optionele bewerkingen kunnen alleen tijdens het aanmaken van een nieuwe of gecertificeerde routing worden toegevoegd.', Comment = '%1=routing no.;%2=routing status';
}
