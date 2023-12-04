resource "aws_iam_group" "dataengineer_group" {
    name = "${var.resource-prefix}-data-engineer"
}

# Additional Policies
resource "aws_iam_group_policy" "lakeformation_role_policy" {
    group  = aws_iam_group.dataengineer_group.name
    policy = jsonencode(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "lakeformation:GetDataAccess",
                        "lakeformation:GrantPermissions",
                        "lakeformation:RevokePermissions",
                        "lakeformation:BatchGrantPermissions",
                        "lakeformation:BatchRevokePermissions",
                        "lakeformation:ListPermissions",
                        "lakeformation:AddLFTagsToResource",
                        "lakeformation:RemoveLFTagsFromResource",
                        "lakeformation:GetResourceLFTags",
                        "lakeformation:ListLFTags",
                        "lakeformation:GetLFTag",
                        "lakeformation:SearchTablesByLFTags",
                        "lakeformation:SearchDatabasesByLFTags",
                        "lakeformation:GetWorkUnits",
                        "lakeformation:GetWorkUnitResults",
                        "lakeformation:StartQueryPlanning",
                        "lakeformation:GetQueryState",
                        "lakeformation:GetQueryStatistics"
                    ],
                    "Resource": "*"
                }
            ]
        }
    )
}

resource "aws_iam_group_policy" "lftags_role_policy" {
    group  = aws_iam_group.dataengineer_group.name
    policy = jsonencode(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "lakeformation:AddLFTagsToResource",
                        "lakeformation:RemoveLFTagsFromResource",
                        "lakeformation:GetResourceLFTags",
                        "lakeformation:ListLFTags",
                        "lakeformation:GetLFTag",
                        "lakeformation:SearchTablesByLFTags",
                        "lakeformation:SearchDatabasesByLFTags"
                    ],
                    "Resource": "*"
                }
            ]
        }
    )
}

# Lake Formation Data Lake Admin Attachments
resource "aws_iam_group_policy_attachment" "dataengineer_glueadmin_attachment" {
    group = aws_iam_group.dataengineer_group.name
    policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}