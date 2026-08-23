namespace Pneuman.ProductionOrderReconciliation;

page 50186 "PNE PIL Raw Lines Part"
{
    ApplicationArea = All;
    Caption = 'Original AutoCAD PIL Rows';
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    PageType = ListPart;
    SourceTable = "PNE PIL Raw Line";

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Source Row No."; Rec."Source Row No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the row number in the uploaded AutoCAD PIL file.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the AutoCAD article number as received.';
                }
                field("Drawing Component No."; Rec."Drawing Component No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies Tek. KompNr as received from AutoCAD.';
                }
                field("Terminal No."; Rec."Terminal No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies KlemNr as received from AutoCAD.';
                }
                field("Quantity Text"; Rec."Quantity Text")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies Art. Aantal exactly as received from AutoCAD.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the parsed AutoCAD quantity. A blank Art. Aantal means one.';
                }
                field("Item Exists"; Rec."Item Exists")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the received article exists in Business Central.';
                }
            }
        }
    }
}
