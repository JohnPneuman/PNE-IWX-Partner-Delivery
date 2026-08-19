pageextension 50159 "PNE Released Prod. Order" extends "Released Production Order"
{
    actions
    {
        addlast(reporting)
        {
            action(PNEFrameSpecification)
            {
                ApplicationArea = All;
                Caption = 'Frame Specification';
                Image = PrintReport;
                ToolTip = 'Creates the frame specification for the BMP configuration linked to this production order.';

                trigger OnAction()
                var
                    ProductionOrder: Record "Production Order";
                    FrameSpecification: Report "PNE Frame Specification";
                begin
                    ProductionOrder := Rec;
                    ProductionOrder.SetRecFilter();
                    FrameSpecification.SetTableView(ProductionOrder);
                    FrameSpecification.RunModal();
                end;
            }
        }
    }
}
