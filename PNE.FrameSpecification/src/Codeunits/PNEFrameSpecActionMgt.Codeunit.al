namespace Pneuman.FrameSpecification;

using Microsoft.Manufacturing.Document;

codeunit 50162 "PNE Frame Spec. Action Mgt."
{
    procedure OpenForProductionOrder(ProductionOrder: Record "Production Order")
    var
        PNEFrameSpecificationReport: Report "PNE Frame Specification";
    begin
        ProductionOrder.SetRecFilter();
        PNEFrameSpecificationReport.SetTableView(ProductionOrder);
        PNEFrameSpecificationReport.RunModal();
    end;
}
