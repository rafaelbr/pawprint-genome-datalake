resource "aws_iam_group" "lakeadmin_group" {
    name = "${var.resource-prefix}-data-lake-admin"
}

# Additional Policies
resource "aws_iam_group_policy" "servicelink_role_policy" {
    group  = aws_iam_group.lakeadmin_group.name
    policy = jsonencode(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "VisualEditor0",
                    "Effect": "Allow",
                    "Action": [
                        "iam:CreateServiceLinkedRole",
                    ],
                    "Resource": "*",
                    "Condition": {
                        "StringEquals": {
                            "iam:AWSServiceName": "lakeformation.amazonaws.com"
                        }
                    }
                }
            ]
        }
    )
}

resource "aws_iam_group_policy" "ram_role_policy" {
    group  = aws_iam_group.lakeadmin_group.name
    policy = jsonencode(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "ram:AcceptResourceShareInvitation",
                        "ram:RejectResourceShareInvitation",
                        "ec2:DescribeAvailabilityZones",
                        "ram:EnableSharingWithAwsOrganization"
                    ],
                    "Resource": "*"
                }
            ]
        }
    )
}

# Lake Formation Data Lake Admin Attachments
resource "aws_iam_group_policy_attachment" "lakeadmin_dataadmin_attachment" {
    group = aws_iam_group.lakeadmin_group.name
    policy_arn = "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin"
}

resource "aws_iam_group_policy_attachment" "lakeadmin_glueadmin_attachment" {
    group = aws_iam_group.lakeadmin_group.name
    policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}

resource "aws_iam_group_policy_attachment" "lakeadmin_cloudwatch_attachment" {
    group = aws_iam_group.lakeadmin_group.name
    policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess"
}

resource "aws_iam_group_policy_attachment" "lakeadmin_crossaccount_attachment" {
    group = aws_iam_group.lakeadmin_group.name
    policy_arn = "arn:aws:iam::aws:policy/AWSLakeFormationCrossAccountManager"
}

resource "aws_iam_group_policy_attachment" "lakeadmin_athena_attachment" {
    group = aws_iam_group.lakeadmin_group.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}