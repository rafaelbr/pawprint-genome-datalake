resource "aws_lakeformation_data_lake_settings" "lakeformation_settings" {
    admins = [aws_iam_user.lf_admin.arn]
}