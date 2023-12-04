resource "aws_iam_user" "lf_admin" {
    name = "geekfox-lakeformation-admin"
}

resource "aws_iam_user_group_membership" "lf_admin_adm" {
    groups = [aws_iam_group.lakeadmin_group.name]
    user   = aws_iam_user.lf_admin.name
}