namespace Pneuman.ProductionOrderReconciliation;

page 50199 "PNE PIL Reason Dialog"
{
    ApplicationArea = All;
    Caption = 'Reden verplicht';
    PageType = StandardDialog;

    layout
    {
        area(content)
        {
            group(Explanation)
            {
                ShowCaption = false;

                field(Heading; Heading)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ShowCaption = false;
                    Style = Strong;
                    ToolTip = 'Geeft aan voor welke actie een reden nodig is.';
                }
                field(Instructions; Instructions)
                {
                    ApplicationArea = All;
                    Editable = false;
                    MultiLine = true;
                    ShowCaption = false;
                    ToolTip = 'Legt uit waarom een reden nodig is.';
                }
            }
            group(ReasonGroup)
            {
                Caption = 'Keuze';

                field(Quantity; Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'Gekozen carrieraantal';
                    DecimalPlaces = 0 : 5;
                    MinValue = 0;
                    ToolTip = 'Geeft het carrieraantal weer dat na uw bewuste keuze voor deze productiecarrier moet gelden.';
                    Visible = QuantityVisible;
                }

                field(Reason; Reason)
                {
                    ApplicationArea = All;
                    Caption = 'Reden';
                    MultiLine = true;
                    ToolTip = 'Voer een duidelijke reden in voor deze bewuste uitzondering.';
                }
            }
        }
    }

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if not (CloseAction in [Action::OK, Action::LookupOK]) then
            exit(true);

        if Reason = '' then begin
            Message(ReasonRequiredMsg);
            exit(false);
        end;

        exit(true);
    end;

    procedure SetContext(NewCaption: Text; NewInstructions: Text)
    begin
        Heading := CopyStr(NewCaption, 1, MaxStrLen(Heading));
        Instructions := CopyStr(NewInstructions, 1, MaxStrLen(Instructions));
        QuantityVisible := false;
    end;

    procedure SetQuantityContext(NewCaption: Text; NewInstructions: Text; DefaultQuantity: Decimal)
    begin
        SetContext(NewCaption, NewInstructions);
        Quantity := DefaultQuantity;
        QuantityVisible := true;
    end;

    procedure GetReason(): Text[250]
    begin
        exit(Reason);
    end;

    procedure GetQuantity(): Decimal
    begin
        exit(Quantity);
    end;

    var
        Heading: Text[100];
        Instructions: Text[500];
        Quantity: Decimal;
        QuantityVisible: Boolean;
        Reason: Text[250];
        ReasonRequiredMsg: Label 'Voer eerst een reden in voordat u doorgaat.';
}
