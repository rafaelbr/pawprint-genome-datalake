resource "aws_iam_group" "dataanalyst_group" {
    name = "${var.resource-prefix}-data-analyst-admin"
}

# Additional Policies
resource "aws_iam_group_policy" "basic_role_policy" {
    group  = aws_iam_group.dataanalyst_group.name
    policy = jsonencode(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "lakeformation:GetDataAccess",
                        "glue:GetTable",
                        "glue:GetTables",
                        "glue:SearchTables",
                        "glue:GetDatabase",
                        "glue:GetDatabases",
                        "glue:GetPartitions",
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

resource "aws_iam_group_policy" "transactions_role_policy" {
    group  = aws_iam_group.dataanalyst_group.name
    policy = jsonencode(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "lakeformation:StartTransaction",
                        "lakeformation:CommitTransaction",
                        "lakeformation:CancelTransaction",
                        "lakeformation:ExtendTransaction",
                        "lakeformation:DescribeTransaction",
                        "lakeformation:ListTransactions",
                        "lakeformation:GetTableObjects",
                        "lakeformation:UpdateTableObjects",
                        "lakeformation:DeleteObjectsOnCancel"
                    ],
                    "Resource": "*"
                }
            ]
        }
    )
}

# Lake Formation Data Lake Admin Attachments
resource "aws_iam_group_policy_attachment" "dataanalyst_athena_attachment" {
    group = aws_iam_group.dataanalyst_group.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}