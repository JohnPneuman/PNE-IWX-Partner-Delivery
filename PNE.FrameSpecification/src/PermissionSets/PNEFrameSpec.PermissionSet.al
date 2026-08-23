namespace Pneuman.FrameSpecification;

permissionset 50155 "PNE Frame Spec."
{
    Assignable = true;
    Caption = 'PNE Frame Specification inrichten';
    IncludedPermissionSets = "PNE Frame Spec. View";
    Permissions = tabledata "PNE Frame Spec. Rule" = RIMD,
                  tabledata "PNE Frame Spec. Line" = RIMD,
                  page "PNE Frame BOM Components" = X,
                  page "PNE Frame Spec. Rules" = X,
                  page "PNE Frame Spec. Test" = X;
}
