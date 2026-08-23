namespace Pneuman.ProductConfigurator;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Routing;

pageextension 50118 "PNE Item Card Routing Repair" extends "Item Card"
{
    actions
    {
        addlast(Functions)
        {
            action(PNERepairOptionalRouting)
            {
                AccessByPermission = tabledata "Routing Line" = I;
                ApplicationArea = All;
                Caption = 'Optionele routing herstellen';
                Image = Recalculate;
                ToolTip = 'Voegt na bevestiging ontbrekende optionele configuratorbewerkingen met tijd nul toe aan de artikelrouting. Gebruik dit alleen voor bestaande configuratorartikelen die vóór deze aanvulling zijn gemaakt.';
                Visible = Rec."IWX Created from Configurator";

                trigger OnAction()
                var
                    IWXRoutingCompleteMgt: Codeunit "PNE IWX Routing Complete Mgt.";
                    AddedLineCount: Integer;
                begin
                    if not Confirm(RepairOptionalRoutingQst, false, Rec."No.", Rec."Routing No.") then
                        exit;

                    AddedLineCount := IWXRoutingCompleteMgt.RepairOptionalRoutingLinesForExistingConfiguredItem(Rec);
                    if AddedLineCount = 0 then
                        Message(NoRoutingLinesAddedMsg)
                    else
                        Message(RoutingLinesAddedMsg, AddedLineCount, Rec."Routing No.");
                end;
            }
        }
    }

    var
        NoRoutingLinesAddedMsg: Label 'De artikelrouting was al compleet of het artikel heeft geen eenduidige opgeslagen IWX-configuratie.';
        RepairOptionalRoutingQst: Label 'Hiermee wordt de gedeelde artikelrouting %2 van configuratorartikel %1 aangevuld met ontbrekende optionele bewerkingen op tijd nul. Dit is een bewuste stamgegevenswijziging voor dit artikel en toekomstige productieorders. Doorgaan?', Comment = '%1 = item number, %2 = routing number';
        RoutingLinesAddedMsg: Label '%1 ontbrekende optionele bewerking(en) zijn met tijd nul toegevoegd aan routing %2. Vernieuw daarna alleen een nog niet verbruikte productieorder.', Comment = '%1 = added routing line count, %2 = routing number';
}
