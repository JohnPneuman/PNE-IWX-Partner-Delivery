page 50153 "PNE Frame Spec. Rules"
{
    ApplicationArea = All;
    Caption = 'Frame Specification Rules';
    PageType = List;
    SourceTable = "PNE Frame Spec. Rule";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Rules)
            {
                field("Frame Configuration Code"; Rec."Frame Configuration Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Item Category Code from Product Configurator table 23044366.';
                }
                field("Configuration Option"; Rec."Configuration Option")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the configuration option that activates the rule.';
                }
                field("Component Type"; Rec."Component Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this rule selects one item or explodes a Production BOM.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Production BOM No."; Rec."Production BOM No.")
                {
                    ApplicationArea = All;
                    Enabled = Rec."Component Type" = Rec."Component Type"::"Production BOM";
                    ToolTip = 'Specifies the Production BOM containing the selectable component item.';
                }
                field("Component No."; Rec."Component No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies an Item, or an Item line from the selected Production BOM.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Item: Record Item;
                        ProductionBOMLine: Record "Production BOM Line";
                        ItemList: Page "Item List";
                        BOMComponentLookup: Page "PNE Frame BOM Components";
                    begin
                        if Rec."Component Type" = Rec."Component Type"::Item then begin
                            ItemList.LookupMode(true);
                            if ItemList.RunModal() <> Action::LookupOK then
                                exit(true);
                            ItemList.GetRecord(Item);
                            Rec.Validate("Component No.", Item."No.");
                            Text := Item."No.";
                            CurrPage.Update(true);
                            exit(true);
                        end;
                        if Rec."Production BOM No." = '' then
                            exit(true);
                        ProductionBOMLine.SetRange("Production BOM No.", Rec."Production BOM No.");
                        ProductionBOMLine.SetRange(Type, ProductionBOMLine.Type::Item);
                        BOMComponentLookup.SetTableView(ProductionBOMLine);
                        BOMComponentLookup.LookupMode(true);
                        if BOMComponentLookup.RunModal() <> Action::LookupOK then
                            exit(true);
                        BOMComponentLookup.GetRecord(ProductionBOMLine);
                        Rec.Validate("Component No.", ProductionBOMLine."No.");
                        Rec.Validate(Description, ProductionBOMLine.Description);
                        Rec.Validate(Quantity, ProductionBOMLine.Quantity);
                        Text := ProductionBOMLine."No.";
                        CurrPage.Update(true);
                        exit(true);
                    end;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the printed description.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the printed quantity.';
                }
                field("Use Width"; Rec."Use Width")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether width is calculated.';
                }
                field("Use Height"; Rec."Use Height")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether height is calculated.';
                }
                field("Width Correction (mm)"; Rec."Width Correction (mm)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the AccountView width correction in millimetres.';
                }
                field("Height Correction (mm)"; Rec."Height Correction (mm)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the AccountView height correction in millimetres.';
                }
                field("Sort Order"; Rec."Sort Order")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the print order.';
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the rule is active.';
                }
            }
        }
    }

}
