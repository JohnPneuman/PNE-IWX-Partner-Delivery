codeunit 50115 "PNE IWX Extended Text Mgt."
{
    procedure PrepareSalesExtendedText(
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        SalesLine: Record "Sales Line")
    var
        TempConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
        HasIncludedItemText: Boolean;
        NextLineNo: Integer;
    begin
        if not TryLoadSalesLineConfiguration(
            TempConfiguratorBOM,
            SalesLine)
        then
            exit;

        InspectConfigurationTextTypes(
            TempConfiguratorBOM,
            ActiveConfigurationIDs,
            HasIncludedItemText);
        if not HasIncludedItemText then
            exit;

        TempExtendedTextLine.Reset();
        TempExtendedTextLine.DeleteAll();
        Clear(ActiveConfigurationIDs);

        BuildGroupedConfigurationText(
            TempConfiguratorBOM,
            1,
            TempExtendedTextLine,
            ActiveConfigurationIDs,
            NextLineNo);
    end;

    procedure HasConfiguredSalesExtendedText(SalesLine: Record "Sales Line"): Boolean
    var
        TempConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
        HasIncludedItemText: Boolean;
    begin
        if not TryLoadSalesLineConfiguration(
            TempConfiguratorBOM,
            SalesLine)
        then
            exit(false);

        InspectConfigurationTextTypes(
            TempConfiguratorBOM,
            ActiveConfigurationIDs,
            HasIncludedItemText);
        exit(HasIncludedItemText);
    end;

    local procedure TryLoadSalesLineConfiguration(
        var TempConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        SalesLine: Record "Sales Line"): Boolean
    var
        IWXSalesLineMgt: Codeunit "IWX PC Sales Line Mgt.";
    begin
        if SalesLine."IWX Cfg. Configuration ID" = '' then
            exit(TryLoadCompleteItemConfiguration(
                TempConfiguratorBOM,
                SalesLine));

        IWXSalesLineMgt.GetConfigurationWithSalesLine(
            TempConfiguratorBOM,
            SalesLine);
        exit(not TempConfiguratorBOM.IsEmpty());
    end;

    local procedure TryLoadCompleteItemConfiguration(
        var TempConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        SalesLine: Record "Sales Line"): Boolean
    var
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
        ConfigurationID: Code[20];
    begin
        ConfigurationID := '';
        if (SalesLine.Type <> SalesLine.Type::Item) or
           (SalesLine."No." = '')
        then
            exit(false);

        ConfiguratorBOM.SetRange(
            "Configured Item No.",
            SalesLine."No.");
        if not ConfiguratorBOM.FindSet() then
            exit(false);

        repeat
            if ConfiguratorBOM."Configuration ID" <> '' then
                if ConfigurationID = '' then
                    ConfigurationID := ConfiguratorBOM."Configuration ID"
                else
                    if ConfigurationID <> ConfiguratorBOM."Configuration ID" then
                        exit(false);
        until ConfiguratorBOM.Next() = 0;

        if ConfigurationID = '' then
            exit(false);

        ConfiguratorBOM.SetRange("Configuration ID", ConfigurationID);
        if not ConfiguratorBOM.FindSet() then
            exit(false);

        repeat
            TempConfiguratorBOM.Init();
            TempConfiguratorBOM.TransferFields(ConfiguratorBOM);
            TempConfiguratorBOM.Insert();
        until ConfiguratorBOM.Next() = 0;

        exit(true);
    end;

    local procedure BuildGroupedConfigurationText(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3";
        ParentQuantity: Decimal;
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        var ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
        var NextLineNo: Integer)
    var
        ChildConfiguratorBOM: Record "IWX Configurator BOM v3";
        TempDisplayOrderedBOM: Record "IWX Configurator BOM v3" temporary;
        TempDisplayOrderedChildBOM: Record "IWX Configurator BOM v3" temporary;
        DisplayOrderedBOMLine: Record "IWX Configurator BOM v3";
        ProcessedConfigurationLines: Dictionary of [Text, Boolean];
        GroupStartLineNo: Integer;
        LineQuantity: Decimal;
    begin
        CopyInOptionDisplayOrder(
            ConfiguratorBOM,
            TempDisplayOrderedBOM);
        GroupStartLineNo := NextLineNo;
        AppendCurrentConfigurationTextInDisplayOrder(
            TempDisplayOrderedBOM,
            ParentQuantity,
            TempExtendedTextLine,
            NextLineNo);
        if NextLineNo > GroupStartLineNo then
            AppendBlankOutputLine(
                TempExtendedTextLine,
                NextLineNo);

        while FindNextDisplayOrderedLine(
            TempDisplayOrderedBOM,
            ProcessedConfigurationLines,
            DisplayOrderedBOMLine)
        do
            if DisplayOrderedBOMLine."Choice Configuration ID" <> '' then
                if EnterConfiguration(
                    DisplayOrderedBOMLine."Choice Configuration ID",
                    ActiveConfigurationIDs)
                then begin
                    SetChildConfigurationFilters(
                        ChildConfiguratorBOM,
                        DisplayOrderedBOMLine);
                    CopyInOptionDisplayOrder(
                        ChildConfiguratorBOM,
                        TempDisplayOrderedChildBOM);
                    LineQuantity :=
                        ParentQuantity *
                        DisplayOrderedBOMLine."Quantity per Unit";
                    BuildGroupedConfigurationText(
                        TempDisplayOrderedChildBOM,
                        LineQuantity,
                        TempExtendedTextLine,
                        ActiveConfigurationIDs,
                        NextLineNo);
                    ActiveConfigurationIDs.Remove(
                        DisplayOrderedBOMLine."Choice Configuration ID");
                    TempDisplayOrderedChildBOM.Reset();
                    TempDisplayOrderedChildBOM.DeleteAll();
                end;
    end;

    local procedure AppendCurrentConfigurationTextInDisplayOrder(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3";
        ParentQuantity: Decimal;
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        var NextLineNo: Integer)
    var
        DisplayOrderedBOMLine: Record "IWX Configurator BOM v3";
        TempSingleConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        TempSingleExtendedTextLine: Record "Extended Text Line" temporary;
        OptionChoice: Record "IWX Cfg Option Choice v3";
        IWXConfiguratorTextMgt: Codeunit "IWX Configurator Text Mgt.";
        ProcessedConfigurationLines: Dictionary of [Text, Boolean];
        LineQuantity: Decimal;
    begin
        while FindNextDisplayOrderedLine(
            ConfiguratorBOM,
            ProcessedConfigurationLines,
            DisplayOrderedBOMLine)
        do
            if TryGetSelectedOptionChoice(
                DisplayOrderedBOMLine,
                OptionChoice)
            then
                if (OptionChoice.Type = OptionChoice.Type::Item) and
                   (OptionChoice."Add Extended Text" =
                    OptionChoice."Add Extended Text"::"Include Item Extended Text")
                then begin
                    LineQuantity :=
                        ParentQuantity *
                        DisplayOrderedBOMLine."Quantity per Unit";
                    if LineQuantity <> 0 then
                        AppendDutchItemExtendedText(
                            OptionChoice."No.",
                            LineQuantity,
                            TempExtendedTextLine,
                            NextLineNo);
                end else begin
                    TempSingleConfiguratorBOM.Copy(
                        ConfiguratorBOM,
                        true);
                    TempSingleConfiguratorBOM.SetRange(
                        "Item Category Code",
                        DisplayOrderedBOMLine."Item Category Code");
                    TempSingleConfiguratorBOM.SetRange(
                        "Configuration Option",
                        DisplayOrderedBOMLine."Configuration Option");
                    TempSingleConfiguratorBOM.SetRange(
                        "Configured Item No.",
                        DisplayOrderedBOMLine."Configured Item No.");
                    IWXConfiguratorTextMgt.BuildTempExtendedTextWithConfiguratorBOM(
                        TempSingleExtendedTextLine,
                        TempSingleConfiguratorBOM);
                    AppendIWXTextLines(
                        TempSingleExtendedTextLine,
                        TempExtendedTextLine,
                        NextLineNo);
                    TempSingleConfiguratorBOM.Reset();
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
        var ConfiguratorBOM: Record "IWX Configurator BOM v3";
        var TempDisplayOrderedBOM: Record "IWX Configurator BOM v3" temporary)
    var
        ConfiguratorOption: Record "IWX Configurator Option v3";
    begin
        TempDisplayOrderedBOM.Reset();
        TempDisplayOrderedBOM.DeleteAll();

        if ConfiguratorBOM.FindSet() then
            repeat
                TempDisplayOrderedBOM.Init();
                TempDisplayOrderedBOM.TransferFields(ConfiguratorBOM);
                if FindConfiguratorOption(
                    ConfiguratorBOM,
                    ConfiguratorOption)
                then
                    TempDisplayOrderedBOM."Display Order" :=
                        ConfiguratorOption."Display Order";
                TempDisplayOrderedBOM.Insert();
            until ConfiguratorBOM.Next() = 0;

        TempDisplayOrderedBOM.SetCurrentKey("Display Order");
        TempDisplayOrderedBOM.SetAscending("Display Order", true);
    end;

    local procedure FindConfiguratorOption(
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
        var ConfiguratorOption: Record "IWX Configurator Option v3"): Boolean
    begin
        if ConfiguratorOption.Get(
            ConfiguratorBOM."Item Category Code",
            ConfiguratorBOM."Configuration Option")
        then
            exit(true);

        ConfiguratorOption.Reset();
        ConfiguratorOption.SetRange(
            Code,
            ConfiguratorBOM."Configuration Option");
        exit(ConfiguratorOption.FindFirst());
    end;

    local procedure FindNextDisplayOrderedLine(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3";
        var ProcessedConfigurationLines: Dictionary of [Text, Boolean];
        var DisplayOrderedBOMLine: Record "IWX Configurator BOM v3"): Boolean
    var
        ConfigurationLineKey: Text;
        HasCandidate: Boolean;
    begin
        if ConfiguratorBOM.FindSet() then
            repeat
                ConfigurationLineKey :=
                    GetConfigurationLineKey(ConfiguratorBOM);
                if not ProcessedConfigurationLines.ContainsKey(
                    ConfigurationLineKey)
                then
                    if (not HasCandidate) or
                       IsBeforeDisplayOrderedLine(
                            ConfiguratorBOM,
                            DisplayOrderedBOMLine)
                    then begin
                        DisplayOrderedBOMLine := ConfiguratorBOM;
                        HasCandidate := true;
                    end;
            until ConfiguratorBOM.Next() = 0;

        if not HasCandidate then
            exit(false);

        ProcessedConfigurationLines.Add(
            GetConfigurationLineKey(DisplayOrderedBOMLine),
            true);
        exit(true);
    end;

    local procedure IsBeforeDisplayOrderedLine(
        CandidateBOMLine: Record "IWX Configurator BOM v3";
        CurrentBOMLine: Record "IWX Configurator BOM v3"): Boolean
    begin
        if CandidateBOMLine."Display Order" <>
           CurrentBOMLine."Display Order"
        then
            exit(
                CandidateBOMLine."Display Order" <
                CurrentBOMLine."Display Order");

        exit(
            CandidateBOMLine."Configuration Option" <
            CurrentBOMLine."Configuration Option");
    end;

    local procedure GetConfigurationLineKey(
        ConfiguratorBOM: Record "IWX Configurator BOM v3"): Text
    begin
        exit(
            StrSubstNo(
                '%1\%2\%3',
                ConfiguratorBOM."Item Category Code",
                ConfiguratorBOM."Configuration Option",
                ConfiguratorBOM."Configured Item No."));
    end;

    local procedure InspectConfigurationTextTypes(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3";
        var ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
        var HasIncludedItemText: Boolean)
    var
        ChildConfiguratorBOM: Record "IWX Configurator BOM v3";
        OptionChoice: Record "IWX Cfg Option Choice v3";
    begin
        if ConfiguratorBOM.FindSet() then
            repeat
                if TryGetSelectedOptionChoice(ConfiguratorBOM, OptionChoice) then
                    if OptionChoice."Add Extended Text" =
                       OptionChoice."Add Extended Text"::"Include Item Extended Text"
                    then
                        HasIncludedItemText := true;

                if ConfiguratorBOM."Choice Configuration ID" <> '' then
                    if EnterConfiguration(
                        ConfiguratorBOM."Choice Configuration ID",
                        ActiveConfigurationIDs)
                    then begin
                        SetChildConfigurationFilters(
                            ChildConfiguratorBOM,
                            ConfiguratorBOM);
                        InspectConfigurationTextTypes(
                            ChildConfiguratorBOM,
                            ActiveConfigurationIDs,
                            HasIncludedItemText);
                        ActiveConfigurationIDs.Remove(
                            ConfiguratorBOM."Choice Configuration ID");
                    end;
            until ConfiguratorBOM.Next() = 0;
    end;

    local procedure TryGetSelectedOptionChoice(
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
        var OptionChoice: Record "IWX Cfg Option Choice v3"): Boolean
    begin
        if ConfiguratorBOM."Choice Code" = '' then
            exit(false);

        exit(
            OptionChoice.Get(
                ConfiguratorBOM."Item Category Code",
                ConfiguratorBOM."Configuration Option",
                ConfiguratorBOM."Choice Code"));
    end;

    local procedure SetChildConfigurationFilters(
        var ChildConfiguratorBOM: Record "IWX Configurator BOM v3";
        ParentConfiguratorBOM: Record "IWX Configurator BOM v3")
    begin
        ChildConfiguratorBOM.Reset();
        ChildConfiguratorBOM.SetRange(
            "Configuration ID",
            ParentConfiguratorBOM."Choice Configuration ID");
        if ParentConfiguratorBOM."Choice Configured Item No." <> '' then
            ChildConfiguratorBOM.SetRange(
                "Configured Item No.",
                ParentConfiguratorBOM."Choice Configured Item No.");
        ChildConfiguratorBOM.SetCurrentKey("Display Order");
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
