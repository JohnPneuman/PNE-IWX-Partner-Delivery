namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Manufacturing.Document;

table 50172 "PNE PIL Header"
{
    Caption = 'Production Order PIL';
    DataClassification = CustomerContent;
    DrillDownPageId = "PNE PIL Reconciliations";
    LookupPageId = "PNE PIL Reconciliations";

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; DataClassification = SystemMetadata; AutoIncrement = true; }
        field(2; "Production Order Status"; Enum "Production Order Status") { Caption = 'Production Order Status'; DataClassification = CustomerContent; }
        field(3; "Production Order No."; Code[20]) { Caption = 'Production Order No.'; DataClassification = CustomerContent; }
        field(4; Status; Enum "PNE PIL Status") { Caption = 'Status'; DataClassification = CustomerContent; }
        field(5; "Source File Name"; Text[250]) { Caption = 'Source File Name'; DataClassification = CustomerContent; }
        field(6; "Created At"; DateTime) { Caption = 'Created At'; DataClassification = SystemMetadata; }
        field(7; "Created By"; Text[50]) { Caption = 'Created By'; DataClassification = EndUserIdentifiableInformation; }
        field(8; "Prepared At"; DateTime) { Caption = 'Prepared At'; DataClassification = SystemMetadata; }
        field(9; "Applied At"; DateTime) { Caption = 'Applied At'; DataClassification = SystemMetadata; }
        field(10; "Applied By"; Text[50]) { Caption = 'Applied By'; DataClassification = EndUserIdentifiableInformation; }
    }

    keys { key(PK; "Entry No.") { Clustered = true; } }

    trigger OnModify()
    var
        StoredPNEPILHeader: Record "PNE PIL Header";
    begin
        if StoredPNEPILHeader.Get("Entry No.") and
           (StoredPNEPILHeader.Status = StoredPNEPILHeader.Status::Applied)
        then
            Error(AppliedHeaderChangeErr);
    end;

    trigger OnDelete()
    begin
        Error(HeaderDeleteErr);
    end;

    var
        AppliedHeaderChangeErr: Label 'Een toegepast PIL-dossier kan niet meer worden gewijzigd.';
        HeaderDeleteErr: Label 'PIL-dossiers zijn auditregistraties en kunnen niet worden verwijderd.';
}
