resource "aws_glue_catalog_database" "trusted_db" {
  name = "${var.resource-prefix}-trusted"
}

resource "aws_glue_catalog_database" "refined_db" {
  name = "${var.resource-prefix}-refined"
}

resource "aws_glue_crawler" "trusted_db_crawler" {
    database_name = "${var.resource-prefix}-trusted"
    name          = "${var.resource-prefix}-trusted-crawler"
    role          = aws_iam_role.glue_crawler_role.arn
    iceberg_target {
        paths = ["s3://${var.resource-prefix}-trusted/"]
        maximum_traversal_depth = 10
    }
}

resource "aws_glue_crawler" "refined_db_crawler" {
    database_name = "${var.resource-prefix}-refined"
    name          = "${var.resource-prefix}-refined-crawler"
    role          = aws_iam_role.glue_crawler_role.arn
    iceberg_target {
        paths = ["s3://${var.resource-prefix}-refined/"]
        maximum_traversal_depth = 10
    }
}
