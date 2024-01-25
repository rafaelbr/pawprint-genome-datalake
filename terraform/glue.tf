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

resource "aws_glue_job" "processing_taxonomy_job" {
    name     = "geekfox-pawprint-processing-taxonomy"
    role_arn = aws_iam_role.glue_etl_role.arn
    glue_version = "4.0"
    command {
        name        = "glueetl"
        script_location = "s3://${var.resource-prefix}-resources/glue_scripts/processing/taxonomy_process.py"
    }
    default_arguments = {
        "--datalake-formats" : "iceberg",
        "--conf" : "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions --conf spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.catalog.glue_catalog.warehouse=s3://geekfox-pawprint-trusted/ --conf spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog --conf spark.sql.catalog.glue_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO --conf spark.sql.catalog.glue_catalog.glue.skip-name-validation=true",
        "--raw_path" : "s3://${var.resource-prefix}-raw/taxonomy/taxonomy/",
        "--trusted_path": "s3://${var.resource-prefix}-trusted"
    }
}

resource "aws_glue_job" "processing_genome_job" {
    name     = "geekfox-pawprint-processing-genome"
    role_arn = aws_iam_role.glue_etl_role.arn
    glue_version = "4.0"
    command {
        name        = "glueetl"
        script_location = "s3://${var.resource-prefix}-resources/glue_scripts/processing/dataset_report_process.py"
    }
    default_arguments = {
        "--datalake-formats" : "iceberg",
        "--conf" : "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions --conf spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.catalog.glue_catalog.warehouse=s3://geekfox-pawprint-trusted/ --conf spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog --conf spark.sql.catalog.glue_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO --conf spark.sql.catalog.glue_catalog.glue.skip-name-validation=true",
        "--raw_path" : "s3://${var.resource-prefix}-raw/genome/dataset_report/",
        "--trusted_path": "s3://${var.resource-prefix}-trusted",
        "--config_bucket": "geekfox-pawprint-resources",
        "--additional-python-modules": "awswrangler"
    }
}