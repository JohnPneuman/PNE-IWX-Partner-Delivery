namespace Pneuman.FrameSpecification;

using Microsoft.Foundation.Company;
using Microsoft.Manufacturing.Document;
using Microsoft.Projects.Project.Job;
using Microsoft.Sales.Document;
using System.Utilities;

report 50158 "PNE Frame Specification"
{
    ApplicationArea = All;
    Caption = 'Frame Specification';
    DefaultRenderingLayout = FrameSpecificationWord;
    UsageCategory = None;

    dataset
    {
        dataitem(ProductionOrder; "Production Order")
        {
            DataItemTableView = sorting(Status, "No.");
            RequestFilterFields = Status, "No.";

            column(CompanyName; CompanyName) { }
            column(DocumentTitle; DocumentTitleLbl) { }
            column(ReportDate; ReportDateText) { }
            column(ReportTime; ReportTimeText) { }
            column(ProductionOrderNo; "No.") { }
            column(ProductionOrderDescription; Description) { }
            column(ConfigurationID; ConfigurationID) { }
            column(ConfiguredItemNo; ConfiguredItemNo) { }
            column(ObjectNo; ObjectNo) { }
            column(ObjectDescription; ObjectDescription) { }
            column(ProjectNo; ProjectNo) { }
            column(ProjectDescription; ProjectDescription) { }
            column(CustomerNo; CustomerNo) { }
            column(CustomerName; CustomerName) { }
            column(ProjectLeader; ProjectLeader) { }
            column(PreparedBy; PreparedBy) { }
            column(FrameCode; FrameCode) { }
            column(FrontCode; FrontCode) { }
            column(ColorCode; ColorCode) { }
            column(SpecialText; SpecialText) { }
            column(NoteText; NoteText) { }
            column(FrameQuantity; FrameQuantityText) { }
            column(FrameWidth; FrameWidthText) { }
            column(FrameHeight; FrameHeightText) { }
            column(FrameDepth; FrameDepthText) { }

            dataitem(FrameLineLoop; Integer)
            {
                DataItemTableView = sorting(Number);

                column(LineConfigurationOption; LineConfigurationOption) { }
                column(LineItemNo; LineItemNo) { }
                column(LineDescription; LineDescription) { }
                column(LineQuantity; LineQuantityText) { }
                column(LineWidth; LineWidthText) { }
                column(LineHeight; LineHeightText) { }

                trigger OnPreDataItem()
                begin
                    SetRange(Number, 1, LineCount);
                    TempPNEFrameSpecLine.Reset();
                    TempPNEFrameSpecLine.SetCurrentKey(Description, "Line No.");
                end;

                trigger OnAfterGetRecord()
                begin
                    if Number = 1 then begin
                        if not TempPNEFrameSpecLine.FindFirst() then
                            CurrReport.Break();
                    end else
                        TempPNEFrameSpecLine.Next();

                    LineConfigurationOption := TempPNEFrameSpecLine."Configuration Option";
                    LineItemNo := TempPNEFrameSpecLine."Item No.";
                    LineDescription := TempPNEFrameSpecLine.Description;
                    LineQuantityText := FormatQuantity(TempPNEFrameSpecLine.Quantity);
                    LineWidthText := FormatDimension(TempPNEFrameSpecLine."Width (mm)");
                    LineHeightText := FormatDimension(TempPNEFrameSpecLine."Height (mm)");
                end;
            }

            trigger OnAfterGetRecord()
            begin
                PrepareReport(ProductionOrder);
            end;
        }
    }

    rendering
    {
        layout(FrameSpecificationWord)
        {
            Type = Word;
            LayoutFile = 'Layouts/PNEFrameSpecification.docx';
            Caption = 'Frame Specification';
            Summary = 'Production frame specification with configuration dimensions and calculated material lines.';
        }
    }

    local procedure PrepareReport(var ProductionOrder: Record "Production Order")
    var
        CompanyInformation: Record "Company Information";
        CurrentDateTimeValue: DateTime;
        FrameHeight: Decimal;
        FrameDepth: Decimal;
        FrameQuantity: Decimal;
        FrameWidth: Decimal;
    begin
        ClearReportValues();

        PNEFrameSpecMgt.BuildLinesFromProductionOrder(
            ProductionOrder,
            TempPNEFrameSpecLine,
            ConfigurationID,
            ProductionOrderLineNo,
            ConfiguredItemNo);
        PNEFrameSpecMgt.GetConfigurationHeader(
            ConfigurationID,
            ObjectDescription,
            FrameCode,
            FrontCode,
            ColorCode,
            SpecialText,
            NoteText,
            FrameQuantity,
            FrameWidth,
            FrameHeight,
            FrameDepth);

        LoadSalesAndProjectValues(ConfigurationID);
        if ObjectNo = '' then
            ObjectNo := ConfiguredItemNo;
        if ObjectDescription = '' then
            ObjectDescription := CopyStr(ProductionOrder.Description, 1, MaxStrLen(ObjectDescription));

        if CompanyInformation.Get() then
            CompanyName := CompanyInformation.Name;
        CurrentDateTimeValue := CurrentDateTime();
        ReportDateText := Format(DT2Date(CurrentDateTimeValue), 0, '<Day,2>-<Month,2>-<Year4>');
        ReportTimeText := Format(DT2Time(CurrentDateTimeValue), 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>');
        FrameQuantityText := FormatQuantity(FrameQuantity);
        FrameWidthText := FormatDimension(FrameWidth);
        FrameHeightText := FormatDimension(FrameHeight);
        FrameDepthText := FormatDimension(FrameDepth);
        LineCount := TempPNEFrameSpecLine.Count();
    end;

    local procedure LoadSalesAndProjectValues(ConfigurationIDToFind: Code[20])
    var
        Job: Record Job;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("IWX Cfg. Configuration ID", ConfigurationIDToFind);
        if not SalesLine.FindFirst() then
            exit;

        ProjectNo := SalesLine."Job No.";
        if Job.Get(ProjectNo) then begin
            ProjectDescription := Job.Description;
            ProjectLeader := Job."Person Responsible";
        end;

        if SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.") then begin
            CustomerNo := SalesHeader."Sell-to Customer No.";
            CustomerName := SalesHeader."Sell-to Customer Name";
            PreparedBy := SalesHeader."Assigned User ID";
            if ProjectNo = '' then begin
                ProjectNo := SalesHeader."No.";
                ProjectDescription := SalesHeader."Your Reference";
            end;
        end;
    end;

    local procedure ClearReportValues()
    begin
        TempPNEFrameSpecLine.Reset();
        TempPNEFrameSpecLine.DeleteAll();
        Clear(ConfigurationID);
        Clear(ConfiguredItemNo);
        Clear(ProductionOrderLineNo);
        Clear(CompanyName);
        Clear(ObjectNo);
        Clear(ObjectDescription);
        Clear(ProjectNo);
        Clear(ProjectDescription);
        Clear(CustomerNo);
        Clear(CustomerName);
        Clear(ProjectLeader);
        Clear(PreparedBy);
        Clear(FrameCode);
        Clear(FrontCode);
        Clear(ColorCode);
        Clear(SpecialText);
        Clear(NoteText);
        Clear(FrameQuantityText);
        Clear(FrameWidthText);
        Clear(FrameHeightText);
        Clear(FrameDepthText);
        Clear(LineCount);
    end;

    local procedure FormatDimension(Value: Decimal): Text[30]
    begin
        if Value = 0 then
            exit('');
        exit(StrSubstNo(DimensionWithUnitLbl, Format(Value, 0, '<Precision,1:1><Standard Format,0>')));
    end;

    local procedure FormatQuantity(Value: Decimal): Text[30]
    begin
        exit(Format(Value, 0, '<Precision,0:5><Standard Format,0>'));
    end;

    var
        TempPNEFrameSpecLine: Record "PNE Frame Spec. Line" temporary;
        PNEFrameSpecMgt: Codeunit "PNE Frame Spec. Mgt.";
        ConfigurationID: Code[20];
        ConfiguredItemNo: Code[20];
        ProductionOrderLineNo: Integer;
        CompanyName: Text[100];
        ObjectNo: Code[20];
        ObjectDescription: Text[100];
        ProjectNo: Code[20];
        ProjectDescription: Text[100];
        CustomerNo: Code[20];
        CustomerName: Text[100];
        ProjectLeader: Code[50];
        PreparedBy: Code[50];
        FrameCode: Code[20];
        FrontCode: Code[20];
        ColorCode: Code[20];
        SpecialText: Text[100];
        NoteText: Text[250];
        FrameQuantityText: Text[30];
        FrameWidthText: Text[30];
        FrameHeightText: Text[30];
        FrameDepthText: Text[30];
        ReportDateText: Text[30];
        ReportTimeText: Text[30];
        LineCount: Integer;
        LineConfigurationOption: Code[20];
        LineItemNo: Code[20];
        LineDescription: Text[100];
        LineQuantityText: Text[30];
        LineWidthText: Text[30];
        LineHeightText: Text[30];
        DocumentTitleLbl: Label 'Frame specification';
        DimensionWithUnitLbl: Label '%1 mm', Comment = '%1 = formatted dimension';
}
