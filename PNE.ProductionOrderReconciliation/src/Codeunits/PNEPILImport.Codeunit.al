namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;

codeunit 50177 "PNE PIL Import"
{
    Permissions =
        tabledata "PNE PIL Group" = r,
        tabledata "PNE PIL Group Item" = r,
        tabledata "PNE PIL Header" = rim,
        tabledata "PNE PIL Line" = rim,
        tabledata "PNE PIL Raw Line" = ri,
        tabledata Item = r,
        tabledata "Production Order" = r;

    procedure ImportForProductionOrder(ProductionOrder: Record "Production Order"; var PNEPILHeader: Record "PNE PIL Header")
    var
        FileName: Text;
        InStream: InStream;
    begin
        Clear(PNEPILHeader);
        CheckSupportedProductionOrder(ProductionOrder);
        if not UploadIntoStream(ImportPILLbl, '', TextFileFilterLbl, FileName, InStream) then
            exit;

        CreateHeader(ProductionOrder, FileName, PNEPILHeader);
        ImportLines(InStream, PNEPILHeader);
    end;

    local procedure CreateHeader(ProductionOrder: Record "Production Order"; FileName: Text; var PNEPILHeader: Record "PNE PIL Header")
    begin
        CheckSupportedProductionOrder(ProductionOrder);
        PNEPILHeader.Init();
        if StrLen(FileName) > MaxStrLen(PNEPILHeader."Source File Name") then
            Error(SourceFileNameTooLongErr, FileName, MaxStrLen(PNEPILHeader."Source File Name"));
        if StrLen(UserId()) > MaxStrLen(PNEPILHeader."Created By") then
            Error(UserIdTooLongErr, MaxStrLen(PNEPILHeader."Created By"));
        PNEPILHeader."Production Order Status" := ProductionOrder.Status;
        PNEPILHeader."Production Order No." := ProductionOrder."No.";
        PNEPILHeader.Status := PNEPILHeader.Status::Imported;
        PNEPILHeader."Source File Name" := CopyStr(FileName, 1, MaxStrLen(PNEPILHeader."Source File Name"));
        PNEPILHeader."Created At" := CurrentDateTime();
        PNEPILHeader."Created By" := CopyStr(UserId(), 1, MaxStrLen(PNEPILHeader."Created By"));
        PNEPILHeader.Insert(true);
    end;

    local procedure ImportLines(InStream: InStream; PNEPILHeader: Record "PNE PIL Header")
    var
        Item: Record Item;
        PNEPILGroup: Record "PNE PIL Group";
        PNEPILGroupItem: Record "PNE PIL Group Item";
        DrawingComponentNo: Text;
        Description: Text[100];
        GroupCode: Code[20];
        ItemExists: Boolean;
        ItemNo: Code[20];
        Quantity: Decimal;
        QuantityText: Text;
        RawPILRow: Text;
        TerminalNo: Text;
        EnabledGroupCount: Integer;
        ParsedRowCount: Integer;
        PositivePILRowCount: Integer;
        RowNo: Integer;
        UsablePositivePILRowCount: Integer;
    begin
        while not InStream.EOS do begin
            Clear(RawPILRow);
            InStream.ReadText(RawPILRow);
            RowNo += 1;
            if DelChr(RawPILRow, '<>', ' ') <> '' then begin
                ParsedRowCount += 1;
                ParsePILRow(RawPILRow, RowNo, ItemNo, DrawingComponentNo, TerminalNo, QuantityText);
                if ItemNo = '' then
                    Error(MissingItemErr, RowNo);

                Quantity := GetQuantity(RowNo, QuantityText);
                ItemExists := Item.Get(ItemNo);
                Clear(Description);
                Clear(GroupCode);
                Clear(EnabledGroupCount);
                if ItemExists then begin
                    Description := Item.Description;
                    PNEPILGroupItem.SetRange("Item No.", ItemNo);
                    PNEPILGroupItem.SetRange(Enabled, true);
                    if PNEPILGroupItem.FindSet() then
                        repeat
                            if PNEPILGroup.Get(PNEPILGroupItem."Group Code") and PNEPILGroup.Enabled then begin
                                EnabledGroupCount += 1;
                                GroupCode := PNEPILGroupItem."Group Code";
                            end;
                        until PNEPILGroupItem.Next() = 0;
                    if EnabledGroupCount > 1 then
                        Error(AmbiguousGroupErr, ItemNo);
                end;

                if Quantity > 0 then begin
                    PositivePILRowCount += 1;
                    if ItemExists then
                        UsablePositivePILRowCount += 1;
                end;

                AddRawLine(PNEPILHeader, RowNo, ItemNo, DrawingComponentNo, TerminalNo, QuantityText, Quantity, ItemExists);
                AddAggregatedLine(PNEPILHeader, ItemNo, Description, Quantity, GroupCode);
            end;
        end;

        if ParsedRowCount = 0 then
            Error(EmptyPILFileErr);
        if PositivePILRowCount = 0 then
            Error(NoPositivePILRowsErr);
        if UsablePositivePILRowCount = 0 then
            Error(NoUsablePILRowsErr);
    end;

    local procedure AddRawLine(PNEPILHeader: Record "PNE PIL Header"; RowNo: Integer; ItemNo: Code[20]; DrawingComponentNo: Text; TerminalNo: Text; QuantityText: Text; Quantity: Decimal; ItemExists: Boolean)
    var
        PNEPILRawLine: Record "PNE PIL Raw Line";
    begin
        PNEPILRawLine.Init();
        if StrLen(DrawingComponentNo) > MaxStrLen(PNEPILRawLine."Drawing Component No.") then
            Error(RawFieldTooLongErr, RowNo, DrawingComponentFieldLbl, MaxStrLen(PNEPILRawLine."Drawing Component No."));
        if StrLen(TerminalNo) > MaxStrLen(PNEPILRawLine."Terminal No.") then
            Error(RawFieldTooLongErr, RowNo, TerminalFieldLbl, MaxStrLen(PNEPILRawLine."Terminal No."));
        if StrLen(QuantityText) > MaxStrLen(PNEPILRawLine."Quantity Text") then
            Error(RawFieldTooLongErr, RowNo, QuantityFieldLbl, MaxStrLen(PNEPILRawLine."Quantity Text"));
        PNEPILRawLine."Header Entry No." := PNEPILHeader."Entry No.";
        PNEPILRawLine."Source Row No." := RowNo;
        PNEPILRawLine."Item No." := ItemNo;
        PNEPILRawLine."Drawing Component No." := CopyStr(DrawingComponentNo, 1, MaxStrLen(PNEPILRawLine."Drawing Component No."));
        PNEPILRawLine."Terminal No." := CopyStr(TerminalNo, 1, MaxStrLen(PNEPILRawLine."Terminal No."));
        PNEPILRawLine."Quantity Text" := CopyStr(QuantityText, 1, MaxStrLen(PNEPILRawLine."Quantity Text"));
        PNEPILRawLine.Quantity := Quantity;
        PNEPILRawLine."Item Exists" := ItemExists;
        PNEPILRawLine.Insert(true);
    end;

    local procedure AddAggregatedLine(PNEPILHeader: Record "PNE PIL Header"; ItemNo: Code[20]; Description: Text[100]; Quantity: Decimal; GroupCode: Code[20])
    var
        PNEPILLine: Record "PNE PIL Line";
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILLine.SetRange("Item No.", ItemNo);
        if PNEPILLine.FindFirst() then begin
            PNEPILLine.Quantity += Quantity;
            PNEPILLine.Modify(true);
            exit;
        end;

        PNEPILLine.Init();
        PNEPILLine."Header Entry No." := PNEPILHeader."Entry No.";
        PNEPILLine."Line No." := GetNextLineNo(PNEPILHeader);
        PNEPILLine."Item No." := ItemNo;
        PNEPILLine.Description := Description;
        PNEPILLine.Quantity := Quantity;
        PNEPILLine."Group Code" := GroupCode;
        PNEPILLine.Insert(true);
    end;

    local procedure GetNextLineNo(PNEPILHeader: Record "PNE PIL Header"): Integer
    var
        PNEPILLine: Record "PNE PIL Line";
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindLast() then
            exit(PNEPILLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure GetQuantity(RowNo: Integer; QuantityText: Text): Decimal
    var
        Quantity: Decimal;
    begin
        if DelChr(QuantityText, '<>', ' ') = '' then
            exit(1);
        if not TryParsePILQuantity(QuantityText, Quantity) then
            Error(InvalidQuantityErr, RowNo, QuantityText);
        if Quantity < 0 then
            Error(NegativeQuantityErr, RowNo);
        if Quantity <> Round(Quantity, 0.00001) then
            Error(TooManyQuantityDecimalsErr, RowNo, QuantityText);
        exit(Quantity);
    end;

    local procedure CheckSupportedProductionOrder(ProductionOrder: Record "Production Order")
    var
        CurrentProductionOrder: Record "Production Order";
    begin
        if ProductionOrder."No." = '' then
            Error(MissingProductionOrderErr);
        if not CurrentProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.") then
            Error(ProductionOrderNotFoundErr, ProductionOrder."No.");
        if not (CurrentProductionOrder.Status in [
                CurrentProductionOrder.Status::Simulated,
                CurrentProductionOrder.Status::"Firm Planned",
                CurrentProductionOrder.Status::Released])
        then
            Error(UnsupportedOrderStatusErr, CurrentProductionOrder."No.");
    end;

    local procedure TryParsePILQuantity(QuantityText: Text; var Quantity: Decimal): Boolean
    var
        CurrentCharacter: Text[1];
        FractionalPart: Decimal;
        FractionalDivisor: Decimal;
        IntegralPart: Decimal;
        CharacterNo: Integer;
        Digit: Integer;
        FirstCharacterNo: Integer;
        HasFractionDigit: Boolean;
        HasDigit: Boolean;
        HasDecimalSeparator: Boolean;
        IsNegative: Boolean;
    begin
        QuantityText := DelChr(QuantityText, '<>', ' ');
        if QuantityText = '' then
            exit(false);

        FirstCharacterNo := 1;
        if CopyStr(QuantityText, 1, 1) = '-' then begin
            IsNegative := true;
            FirstCharacterNo := 2;
        end;

        for CharacterNo := FirstCharacterNo to StrLen(QuantityText) do begin
            CurrentCharacter := CopyStr(QuantityText, CharacterNo, 1);
            if StrPos('0123456789', CurrentCharacter) > 0 then begin
                Evaluate(Digit, CurrentCharacter);
                HasDigit := true;
                if HasDecimalSeparator then begin
                    FractionalPart := FractionalPart * 10 + Digit;
                    FractionalDivisor := FractionalDivisor * 10;
                    HasFractionDigit := true;
                end else
                    IntegralPart := IntegralPart * 10 + Digit;
            end else
                if ((CurrentCharacter = ',') or (CurrentCharacter = '.')) and not HasDecimalSeparator then begin
                    HasDecimalSeparator := true;
                    FractionalDivisor := 1;
                end else
                    exit(false);
        end;

        if not HasDigit or (HasDecimalSeparator and not HasFractionDigit) then
            exit(false);

        Quantity := IntegralPart;
        if HasDecimalSeparator then
            Quantity += FractionalPart / FractionalDivisor;
        if IsNegative then
            Quantity := -Quantity;
        exit(true);
    end;

    local procedure ParsePILRow(RawPILRow: Text; RowNo: Integer; var ItemNo: Code[20]; var DrawingComponentNo: Text; var TerminalNo: Text; var QuantityText: Text)
    var
        PILFields: array[4] of Text;
        CurrentCharacter: Text[1];
        CurrentField: Text;
        CharacterNo: Integer;
        FieldNo: Integer;
        FieldHasClosingSingleQuote: Boolean;
        FieldHasOpeningSingleQuote: Boolean;
        IsInsideSingleQuotes: Boolean;
    begin
        FieldNo := 1;
        for CharacterNo := 1 to StrLen(RawPILRow) do begin
            CurrentCharacter := CopyStr(RawPILRow, CharacterNo, 1);
            if CurrentCharacter = '''' then begin
                if IsInsideSingleQuotes then begin
                    IsInsideSingleQuotes := false;
                    FieldHasClosingSingleQuote := true;
                end else begin
                    if FieldHasOpeningSingleQuote then
                        Error(InvalidPILFormatErr, RowNo);
                    FieldHasOpeningSingleQuote := true;
                    IsInsideSingleQuotes := true;
                end;
            end
            else
                if (CurrentCharacter = ',') and not IsInsideSingleQuotes then begin
                    if not (FieldHasOpeningSingleQuote and FieldHasClosingSingleQuote) then
                        Error(InvalidPILFormatErr, RowNo);
                    if FieldNo = ArrayLen(PILFields) then
                        Error(InvalidPILFormatErr, RowNo);
                    PILFields[FieldNo] := CurrentField;
                    Clear(CurrentField);
                    Clear(FieldHasOpeningSingleQuote);
                    Clear(FieldHasClosingSingleQuote);
                    FieldNo += 1;
                end else
                    if IsInsideSingleQuotes then
                        CurrentField += CurrentCharacter
                    else
                        if CurrentCharacter <> ' ' then
                            Error(InvalidPILFormatErr, RowNo);
        end;

        if IsInsideSingleQuotes or (FieldNo <> ArrayLen(PILFields)) or
           not (FieldHasOpeningSingleQuote and FieldHasClosingSingleQuote)
        then
            Error(InvalidPILFormatErr, RowNo);
        PILFields[FieldNo] := CurrentField;

        if StrLen(DelChr(PILFields[1], '<>', ' ')) > MaxStrLen(ItemNo) then
            Error(ItemNoTooLongErr, RowNo);
        ItemNo := CopyStr(DelChr(PILFields[1], '<>', ' '), 1, MaxStrLen(ItemNo));
        DrawingComponentNo := PILFields[2];
        TerminalNo := PILFields[3];
        QuantityText := PILFields[4];
    end;

    var
        AmbiguousGroupErr: Label 'PIL-artikel %1 hoort bij meer dan één actieve PIL-groep.', Comment = '%1 = item number';
        ImportPILLbl: Label 'AutoCAD-PIL importeren';
        InvalidPILFormatErr: Label 'PIL-regel %1 moet precies vier komma-gescheiden velden tussen enkele aanhalingstekens bevatten.', Comment = '%1 = row number';
        InvalidQuantityErr: Label 'PIL-regel %1 bevat een ongeldig Art. Aantal: %2.', Comment = '%1 = row number, %2 = value';
        ItemNoTooLongErr: Label 'PIL-regel %1 bevat een artikelnummer langer dan 20 tekens.', Comment = '%1 = row number';
        EmptyPILFileErr: Label 'Het geselecteerde PIL-bestand bevat geen AutoCAD-regels.';
        MissingItemErr: Label 'PIL-regel %1 bevat geen artikelnummer.', Comment = '%1 = row number';
        MissingProductionOrderErr: Label 'Kies eerst een bestaande gesimuleerde, vastgeplande of vrijgegeven productieorder voordat je een PIL importeert.';
        NegativeQuantityErr: Label 'PIL-regel %1 bevat een negatief aantal.', Comment = '%1 = row number';
        NoPositivePILRowsErr: Label 'De PIL bevat geen regels met een positief Art. Aantal. Een PIL moet minimaal één positief AutoCAD-artikelaantal bevatten.';
        NoUsablePILRowsErr: Label 'De PIL bevat geen positieve AutoCAD-artikelen die in Business Central bestaan. Maak of corrigeer de artikelen en importeer de PIL opnieuw.';
        ProductionOrderNotFoundErr: Label 'Productieorder %1 bestaat niet meer met de gekozen status.', Comment = '%1 = production order number';
        QuantityFieldLbl: Label 'Art. Aantal';
        RawFieldTooLongErr: Label 'PIL-regel %1 bevat %2 langer dan de ondersteunde auditlengte van %3 tekens. De import is niet opgeslagen, zodat geen bronwaarde is afgekapt.', Comment = '%1 = row number, %2 = AutoCAD field name, %3 = maximum length';
        SourceFileNameTooLongErr: Label 'De geselecteerde PIL-bestandsnaam %1 is langer dan de ondersteunde auditlengte van %2 tekens. Hernoem het bestand voordat je importeert, zodat de audit volledig blijft.', Comment = '%1 = file name, %2 = maximum length';
        TerminalFieldLbl: Label 'KlemNr';
        TextFileFilterLbl: Label 'Tekstbestanden (*.txt;*.csv)|*.txt;*.csv';
        TooManyQuantityDecimalsErr: Label 'PIL-regel %1 bevat Art. Aantal %2 met meer dan vijf decimalen. Gebruik een aantal dat exact kan worden opgeslagen.', Comment = '%1 = row number, %2 = value';
        UnsupportedOrderStatusErr: Label 'Productieorder %1 moet gesimuleerd, vastgepland of vrijgegeven zijn voordat je een PIL kunt importeren.', Comment = '%1 = production order number';
        UserIdTooLongErr: Label 'De huidige gebruikers-id is langer dan de ondersteunde auditlengte van %1 tekens. De PIL is niet geïmporteerd, zodat de auditidentiteit volledig blijft.', Comment = '%1 = maximum length';
        DrawingComponentFieldLbl: Label 'Tek. KompNr';
}
