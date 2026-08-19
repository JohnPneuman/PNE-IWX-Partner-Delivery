namespace Pneuman.ProductConfigurator;

using Microsoft.Foundation.ExtendedText;
using Microsoft.Sales.Document;

codeunit 50115 "PNE IWX Extended Text Mgt."
{
    procedure PrepareSalesExtendedText(
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        SalesLine: Record "Sales Line")
    var
        TempIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
        HasIncludedItemText: Boolean;
        NextLineNo: Integer;
    begin
        if not TryLoadSalesLineConfiguration(
            TempIWXConfiguratorBOMv3,
            SalesLine)
        then
            exit;

        InspectConfigurationTextTypes(
            TempIWXConfiguratorBOMv3,
            ActiveConfigurationIDs,
            HasIncludedItemText);
        if not HasIncludedItemText then
            exit;

        TempExtendedTextLine.Reset();
        TempExtendedTextLine.DeleteAll();
        Clear(ActiveConfigurationIDs);

        BuildGroupedConfigurationText(
            TempIWXConfiguratorBOMv3,
            1,
            TempExtendedTextLine,
            ActiveConfigurationIDs,
            NextLineNo);
    end;

    procedure HasConfiguredSalesExtendedText(SalesLine: Record "Sales Line"): Boolean
    var
        TempIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
        HasIncludedItemText: Boolean;
    begin
        if not TryLoadSalesLineConfiguration(
            TempIWXConfiguratorBOMv3,
            SalesLine)
        then
            exit(false);

        InspectConfigurationTextTypes(
            TempIWXConfiguratorBOMv3,
            ActiveConfigurationIDs,
            HasIncludedItemText);
        exit(HasIncludedItemText);
    end;

    local procedure TryLoadSalesLineConfiguration(
        var TempIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        SalesLine: Record "Sales Line"): Boolean
    var
        IWXPCSalesLineMgt: Codeunit "IWX PC Sales Line Mgt.";
    begin
        if SalesLine."IWX Cfg. Configuration ID" = '' then
            exit(TryLoadCompleteItemConfiguration(
                TempIWXConfiguratorBOMv3,
                SalesLine));

        IWXPCSalesLineMgt.GetConfigurationWithSalesLine(
            TempIWXConfiguratorBOMv3,
            SalesLine);
        exit(not TempIWXConfiguratorBOMv3.IsEmpty());
    end;

    local procedure TryLoadCompleteItemConfiguration(
        var TempIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        SalesLine: Record "Sales Line"): Boolean
    var
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        ConfigurationID: Code[20];
    begin
        ConfigurationID := '';
        if (SalesLine.Type <> SalesLine.Type::Item) or
           (SalesLine."No." = '')
        then
            exit(false);

        IWXConfiguratorBOMv3.SetRange(
            "Configured Item No.",
            SalesLine."No.");
        if not IWXConfiguratorBOMv3.FindSet() then
            exit(false);

        repeat
            if IWXConfiguratorBOMv3."Configuration ID" <> '' then
                if ConfigurationID = '' then
                    ConfigurationID := IWXConfiguratorBOMv3."Configuration ID"
                else
                    if ConfigurationID <> IWXConfiguratorBOMv3."Configuration ID" then
                        exit(false);
        until IWXConfiguratorBOMv3.Next() = 0;

        if ConfigurationID = '' then
            exit(false);

        IWXConfiguratorBOMv3.SetRange("Configuration ID", ConfigurationID);
        if not IWXConfiguratorBOMv3.FindSet() then
            exit(false);

        repeat
            TempIWXConfiguratorBOMv3.Init();
            TempIWXConfiguratorBOMv3.TransferFields(IWXConfiguratorBOMv3);
            TempIWXConfiguratorBOMv3.Insert();
        until IWXConfiguratorBOMv3.Next() = 0;

        exit(true);
    end;

    local procedure BuildGroupedConfigurationText(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        ParentQuantity: Decimal;
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        var ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
        var NextLineNo: Integer)
    var
        ChildIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        TempDisplayOrderedIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        TempDisplayOrderedChildIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        DisplayOrderedLineIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        ProcessedConfigurationLines: Dictionary of [Text, Boolean];
        GroupStartLineNo: Integer;
        LineQuantity: Decimal;
    begin
        CopyInOptionDisplayOrder(
            IWXConfiguratorBOMv3,
            TempDisplayOrderedIWXConfiguratorBOMv3);
        GroupStartLineNo := NextLineNo;
        AppendCurrentConfigurationTextInDisplayOrder(
            TempDisplayOrderedIWXConfiguratorBOMv3,
            ParentQuantity,
            TempExtendedTextLine,
            NextLineNo);
        if NextLineNo > GroupStartLineNo then
            AppendBlankOutputLine(
                TempExtendedTextLine,
                NextLineNo);

        while FindNextDisplayOrderedLine(
            TempDisplayOrderedIWXConfiguratorBOMv3,
            ProcessedConfigurationLines,
            DisplayOrderedLineIWXConfiguratorBOMv3)
        do
            if DisplayOrderedLineIWXConfiguratorBOMv3."Choice Configuration ID" <> '' then
                if EnterConfiguration(
                    DisplayOrderedLineIWXConfiguratorBOMv3."Choice Configuration ID",
                    ActiveConfigurationIDs)
                then begin
                    SetChildConfigurationFilters(
                        ChildIWXConfiguratorBOMv3,
                        DisplayOrderedLineIWXConfiguratorBOMv3);
                    CopyInOptionDisplayOrder(
                        ChildIWXConfiguratorBOMv3,
                        TempDisplayOrderedChildIWXConfiguratorBOMv3);
                    LineQuantity :=
                        ParentQuantity *
                        DisplayOrderedLineIWXConfiguratorBOMv3."Quantity per Unit";
                    BuildGroupedConfigurationText(
                        TempDisplayOrderedChildIWXConfiguratorBOMv3,
                        LineQuantity,
                        TempExtendedTextLine,
                        ActiveConfigurationIDs,
                        NextLineNo);
                    ActiveConfigurationIDs.Remove(
                        DisplayOrderedLineIWXConfiguratorBOMv3."Choice Configuration ID");
                    TempDisplayOrderedChildIWXConfiguratorBOMv3.Reset();
                    TempDisplayOrderedChildIWXConfiguratorBOMv3.DeleteAll();
                end;
    end;

    local procedure AppendCurrentConfigurationTextInDisplayOrder(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        ParentQuantity: Decimal;
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        var NextLineNo: Integer)
    var
        DisplayOrderedLineIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        TempSingleIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        TempSingleExtendedTextLine: Record "Extended Text Line" temporary;
        IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3";
        IWXConfiguratorTextMgt: Codeunit "IWX Configurator Text Mgt.";
        ProcessedConfigurationLines: Dictionary of [Text, Boolean];
        LineQuantity: Decimal;
    begin
        while FindNextDisplayOrderedLine(
            IWXConfiguratorBOMv3,
            ProcessedConfigurationLines,
            DisplayOrderedLineIWXConfiguratorBOMv3)
        do
            if TryGetSelectedOptionChoice(
                DisplayOrderedLineIWXConfiguratorBOMv3,
                IWXCfgOptionChoicev3)
            then
                if (IWXCfgOptionChoicev3.Type = IWXCfgOptionChoicev3.Type::Item) and
                   (IWXCfgOptionChoicev3."Add Extended Text" =
                    IWXCfgOptionChoicev3."Add Extended Text"::"Include Item Extended Text")
                then begin
                    LineQuantity :=
                        ParentQuantity *
                        DisplayOrderedLineIWXConfiguratorBOMv3."Quantity per Unit";
                    if LineQuantity <> 0 then
                        AppendDutchItemExtendedText(
                            IWXCfgOptionChoicev3."No.",
                            LineQuantity,
                            TempExtendedTextLine,
                            NextLineNo);
                end else begin
                    TempSingleIWXConfiguratorBOMv3.Copy(
                        IWXConfiguratorBOMv3,
                        true);
                    TempSingleIWXConfiguratorBOMv3.SetRange(
                        "Item Category Code",
                        DisplayOrderedLineIWXConfiguratorBOMv3."Item Category Code");
                    TempSingleIWXConfiguratorBOMv3.SetRange(
                        "Configuration Option",
                        DisplayOrderedLineIWXConfiguratorBOMv3."Configuration Option");
                    TempSingleIWXConfiguratorBOMv3.SetRange(
                        "Configured Item No.",
                        DisplayOrderedLineIWXConfiguratorBOMv3."Configured Item No.");
                    IWXConfiguratorTextMgt.BuildTempExtendedTextWithConfiguratorBOM(
                        TempSingleExtendedTextLine,
                        TempSingleIWXConfiguratorBOMv3);
                    AppendIWXTextLines(
                        TempSingleExtendedTextLine,
                        TempExtendedTextLine,
                        NextLineNo);
                    TempSingleIWXConfiguratorBOMv3.Reset();
                    TempSingleExtendedTextLine.Reset();
                    TempSingleExtendedTextLine.DeleteAll();
                end;
    end;

    local procedure AppendIWXTextLines(
        var TempIWXExtendedTextLine: Record "Extended Text Line" temporary;
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        var NextLineNo: Integer)
    begin
        if TempIWXExtendedTextLine.FindSet() then
            repeat
                if TempIWXExtendedTextLine.Text <> '' then
                    AppendOutputText(
                        TempIWXExtendedTextLine.Text,
                        TempExtendedTextLine,
                        NextLineNo);
            until TempIWXExtendedTextLine.Next() = 0;
    end;

    local procedure CopyInOptionDisplayOrder(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        var TempDisplayOrderedIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary)
    var
        IWXConfiguratorOptionv3: Record "IWX Configurator Option v3";
    begin
        TempDisplayOrderedIWXConfiguratorBOMv3.Reset();
        TempDisplayOrderedIWXConfiguratorBOMv3.DeleteAll();

        if IWXConfiguratorBOMv3.FindSet() then
            repeat
                TempDisplayOrderedIWXConfiguratorBOMv3.Init();
                TempDisplayOrderedIWXConfiguratorBOMv3.TransferFields(IWXConfiguratorBOMv3);
                if FindConfiguratorOption(
                    IWXConfiguratorBOMv3,
                    IWXConfiguratorOptionv3)
                then
                    TempDisplayOrderedIWXConfiguratorBOMv3."Display Order" :=
                        IWXConfiguratorOptionv3."Display Order";
                TempDisplayOrderedIWXConfiguratorBOMv3.Insert();
            until IWXConfiguratorBOMv3.Next() = 0;

        TempDisplayOrderedIWXConfiguratorBOMv3.SetCurrentKey("Display Order");
        TempDisplayOrderedIWXConfiguratorBOMv3.SetAscending("Display Order", true);
    end;

    local procedure FindConfiguratorOption(
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        var IWXConfiguratorOptionv3: Record "IWX Configurator Option v3"): Boolean
    begin
        if IWXConfiguratorOptionv3.Get(
            IWXConfiguratorBOMv3."Item Category Code",
            IWXConfiguratorBOMv3."Configuration Option")
        then
            exit(true);

        IWXConfiguratorOptionv3.Reset();
        IWXConfiguratorOptionv3.SetRange(
            Code,
            IWXConfiguratorBOMv3."Configuration Option");
        exit(IWXConfiguratorOptionv3.FindFirst());
    end;

    local procedure FindNextDisplayOrderedLine(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        var ProcessedConfigurationLines: Dictionary of [Text, Boolean];
        var DisplayOrderedLineIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3"): Boolean
    var
        ConfigurationLineKey: Text;
        HasCandidate: Boolean;
    begin
        if IWXConfiguratorBOMv3.FindSet() then
            repeat
                ConfigurationLineKey :=
                    GetConfigurationLineKey(IWXConfiguratorBOMv3);
                if not ProcessedConfigurationLines.ContainsKey(
                    ConfigurationLineKey)
                then
                    if (not HasCandidate) or
                       IsBeforeDisplayOrderedLine(
                            IWXConfiguratorBOMv3,
                            DisplayOrderedLineIWXConfiguratorBOMv3)
                    then begin
                        DisplayOrderedLineIWXConfiguratorBOMv3 := IWXConfiguratorBOMv3;
                        HasCandidate := true;
                    end;
            until IWXConfiguratorBOMv3.Next() = 0;

        if not HasCandidate then
            exit(false);

        ProcessedConfigurationLines.Add(
            GetConfigurationLineKey(DisplayOrderedLineIWXConfiguratorBOMv3),
            true);
        exit(true);
    end;

    local procedure IsBeforeDisplayOrderedLine(
        CandidateIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        CurrentIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3"): Boolean
    begin
        if CandidateIWXConfiguratorBOMv3."Display Order" <>
           CurrentIWXConfiguratorBOMv3."Display Order"
        then
            exit(
                CandidateIWXConfiguratorBOMv3."Display Order" <
                CurrentIWXConfiguratorBOMv3."Display Order");

        exit(
            CandidateIWXConfiguratorBOMv3."Configuration Option" <
            CurrentIWXConfiguratorBOMv3."Configuration Option");
    end;

    local procedure GetConfigurationLineKey(
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3"): Text
    begin
        exit(
            StrSubstNo(
                '%1\%2\%3',
                IWXConfiguratorBOMv3."Item Category Code",
                IWXConfiguratorBOMv3."Configuration Option",
                IWXConfiguratorBOMv3."Configured Item No."));
    end;

    local procedure InspectConfigurationTextTypes(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        var ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
        var HasIncludedItemText: Boolean)
    var
        ChildIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3";
    begin
        if IWXConfiguratorBOMv3.FindSet() then
            repeat
                if TryGetSelectedOptionChoice(IWXConfiguratorBOMv3, IWXCfgOptionChoicev3) then
                    if IWXCfgOptionChoicev3."Add Extended Text" =
                       IWXCfgOptionChoicev3."Add Extended Text"::"Include Item Extended Text"
                    then
                        HasIncludedItemText := true;

                if IWXConfiguratorBOMv3."Choice Configuration ID" <> '' then
                    if EnterConfiguration(
                        IWXConfiguratorBOMv3."Choice Configuration ID",
                        ActiveConfigurationIDs)
                    then begin
                        SetChildConfigurationFilters(
                            ChildIWXConfiguratorBOMv3,
                            IWXConfiguratorBOMv3);
                        InspectConfigurationTextTypes(
                            ChildIWXConfiguratorBOMv3,
                            ActiveConfigurationIDs,
                            HasIncludedItemText);
                        ActiveConfigurationIDs.Remove(
                            IWXConfiguratorBOMv3."Choice Configuration ID");
                    end;
            until IWXConfiguratorBOMv3.Next() = 0;
    end;

    local procedure TryGetSelectedOptionChoice(
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        var IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3"): Boolean
    begin
        if IWXConfiguratorBOMv3."Choice Code" = '' then
            exit(false);

        exit(
            IWXCfgOptionChoicev3.Get(
                IWXConfiguratorBOMv3."Item Category Code",
                IWXConfiguratorBOMv3."Configuration Option",
                IWXConfiguratorBOMv3."Choice Code"));
    end;

    local procedure SetChildConfigurationFilters(
        var ChildIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        ParentIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3")
    begin
        ChildIWXConfiguratorBOMv3.Reset();
        ChildIWXConfiguratorBOMv3.SetRange(
            "Configuration ID",
            ParentIWXConfiguratorBOMv3."Choice Configuration ID");
        if ParentIWXConfiguratorBOMv3."Choice Configured Item No." <> '' then
            ChildIWXConfiguratorBOMv3.SetRange(
                "Configured Item No.",
                ParentIWXConfiguratorBOMv3."Choice Configured Item No.");
        ChildIWXConfiguratorBOMv3.SetCurrentKey("Display Order");
    end;

    local procedure EnterConfiguration(
        ConfigurationID: Code[20];
        var ActiveConfigurationIDs: Dictionary of [Code[20], Boolean]): Boolean
    begin
        if ActiveConfigurationIDs.ContainsKey(ConfigurationID) then
            Error(
                CircularConfigurationErr,
                ConfigurationID);

        ActiveConfigurationIDs.Add(ConfigurationID, true);
        exit(true);
    end;

    local procedure AppendDutchItemExtendedText(
        ItemNo: Code[20];
        Quantity: Decimal;
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        var NextLineNo: Integer)
    var
        ExtendedTextHeader: Record "Extended Text Header";
        ExtendedTextLine: Record "Extended Text Line";
    begin
        ExtendedTextHeader.SetRange(
            "Table Name",
            ExtendedTextHeader."Table Name"::Item);
        ExtendedTextHeader.SetRange("No.", ItemNo);
        ExtendedTextHeader.SetRange("Sales Quote", true);

        if ExtendedTextHeader.FindSet() then
            repeat
                if IsDutchHeaderValid(ExtendedTextHeader) then begin
                    ExtendedTextLine.SetRange(
                        "Table Name",
                        ExtendedTextHeader."Table Name");
                    ExtendedTextLine.SetRange(
                        "No.",
                        ExtendedTextHeader."No.");
                    ExtendedTextLine.SetRange(
                        "Language Code",
                        ExtendedTextHeader."Language Code");
                    ExtendedTextLine.SetRange(
                        "Text No.",
                        ExtendedTextHeader."Text No.");

                    if ExtendedTextLine.FindSet() then
                        repeat
                            if ExtendedTextLine.Text <> '' then
                                AppendQuantityOutputText(
                                    Quantity,
                                    ExtendedTextLine.Text,
                                    TempExtendedTextLine,
                                    NextLineNo);
                        until ExtendedTextLine.Next() = 0;
                end;
            until ExtendedTextHeader.Next() = 0;
    end;

    local procedure IsDutchHeaderValid(
        ExtendedTextHeader: Record "Extended Text Header"): Boolean
    begin
        if not (
            (ExtendedTextHeader."Language Code" = DutchLanguageCodeLbl) or
            ExtendedTextHeader."All Language Codes")
        then
            exit(false);

        if (ExtendedTextHeader."Starting Date" <> 0D) and
           (ExtendedTextHeader."Starting Date" > WorkDate())
        then
            exit(false);

        if (ExtendedTextHeader."Ending Date" <> 0D) and
           (ExtendedTextHeader."Ending Date" < WorkDate())
        then
            exit(false);

        exit(true);
    end;

    local procedure AppendOutputText(
        OutputText: Text;
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        var NextLineNo: Integer)
    var
        TextPart: Text[100];
    begin
        while OutputText <> '' do begin
            TextPart :=
                CopyStr(
                    OutputText,
                    1,
                    MaxStrLen(TempExtendedTextLine.Text));
            OutputText :=
                CopyStr(
                    OutputText,
                    StrLen(TextPart) + 1);

            NextLineNo += 10000;
            TempExtendedTextLine.Init();
            TempExtendedTextLine."Line No." := NextLineNo;
            TempExtendedTextLine.Text := TextPart;
            TempExtendedTextLine.Insert();
        end;
    end;

    local procedure AppendBlankOutputLine(
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        var NextLineNo: Integer)
    begin
        NextLineNo += 10000;
        TempExtendedTextLine.Init();
        TempExtendedTextLine."Line No." := NextLineNo;
        // A truly empty line can be skipped by the standard transfer routine.
        TempExtendedTextLine.Text := ' ';
        TempExtendedTextLine.Insert();
    end;

    local procedure AppendQuantityOutputText(
        Quantity: Decimal;
        OutputText: Text;
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        var NextLineNo: Integer)
    var
        QuantityPrefix: Text;
        TextPart: Text;
        AvailableTextLength: Integer;
    begin
        QuantityPrefix :=
            StrSubstNo(
                QuantityPrefixLbl,
                Format(Quantity, 0, 9));

        AvailableTextLength :=
            MaxStrLen(TempExtendedTextLine.Text) -
            StrLen(QuantityPrefix);

        while OutputText <> '' do begin
            TextPart :=
                GetWordWrappedTextPart(
                    OutputText,
                    AvailableTextLength);
            OutputText :=
                RemoveWrappedTextPart(
                    OutputText,
                    TextPart);

            NextLineNo += 10000;
            TempExtendedTextLine.Init();
            TempExtendedTextLine."Line No." := NextLineNo;
            TempExtendedTextLine.Text :=
                CopyStr(
                    QuantityPrefix + TextPart,
                    1,
                    MaxStrLen(TempExtendedTextLine.Text));
            TempExtendedTextLine.Insert();
            QuantityPrefix := '';
            AvailableTextLength :=
                MaxStrLen(TempExtendedTextLine.Text);
        end;
    end;

    local procedure GetWordWrappedTextPart(
        OutputText: Text;
        AvailableTextLength: Integer): Text
    var
        BreakPosition: Integer;
    begin
        if StrLen(OutputText) <= AvailableTextLength then
            exit(OutputText);

        BreakPosition := AvailableTextLength;
        while (BreakPosition > 1) and
              (CopyStr(OutputText, BreakPosition, 1) <> ' ')
        do
            BreakPosition -= 1;

        if BreakPosition = 1 then
            exit(CopyStr(OutputText, 1, AvailableTextLength));

        exit(CopyStr(OutputText, 1, BreakPosition - 1));
    end;

    local procedure RemoveWrappedTextPart(
        OutputText: Text;
        TextPart: Text): Text
    var
        NextPosition: Integer;
    begin
        NextPosition := StrLen(TextPart) + 1;
        while (NextPosition <= StrLen(OutputText)) and
              (CopyStr(OutputText, NextPosition, 1) = ' ')
        do
            NextPosition += 1;

        exit(CopyStr(OutputText, NextPosition));
    end;

    var
        CircularConfigurationErr: Label 'Configuration %1 contains a circular sub-configuration reference.', Comment = '%1 = configuration ID';
        DutchLanguageCodeLbl: Label 'NLD', Locked = true;
        QuantityPrefixLbl: Label '%1x ', Comment = '%1 = item quantity';
}
