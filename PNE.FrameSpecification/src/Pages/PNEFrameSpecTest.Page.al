page 50157 "PNE Frame Spec. Test"
{
    ApplicationArea = All;
    Caption = 'Test Frame Specification';
    PageType = Card;
    UsageCategory = Tasks;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(ConfigurationID; ConfigurationID)
                {
                    ApplicationArea = All;
                    Caption = 'BMP Configuration ID';
                    ShowMandatory = true;
                    ToolTip = 'Specifies the top-level BMP configuration to use for the preview.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Preview)
            {
                ApplicationArea = All;
                Caption = 'Create Preview';
                Image = PreviewChecks;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Builds a temporary preview without changing a production order.';

                trigger OnAction()
                begin
                    CreatePreview();
                end;
            }
        }
    }

    local procedure CreatePreview()
    var
        TempFrameSpecLine: Record "PNE Frame Spec. Line" temporary;
        FrameSpecMgt: Codeunit "PNE Frame Spec. Mgt.";
        FrameSpecPreview: Page "PNE Frame Spec. Preview";
    begin
        if ConfigurationID = '' then
            Error(ConfigurationRequiredErr);

        FrameSpecMgt.BuildLinesFromConfigurationID(ConfigurationID, TempFrameSpecLine);
        FrameSpecPreview.SetLines(TempFrameSpecLine);
        FrameSpecPreview.RunModal();
    end;

    var
        ConfigurationID: Code[20];
        ConfigurationRequiredErr: Label 'Enter a BMP Configuration ID before creating the preview.';
}
