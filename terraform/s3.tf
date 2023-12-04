resource "aws_s3_bucket" "raw_bucket" {
    bucket = "${var.resource-prefix}-raw"
}

resource "aws_s3_bucket" "trusted_bucket" {
    bucket = "${var.resource-prefix}-trusted"
}

resource "aws_s3_bucket" "refined_bucket" {
    bucket = "${var.resource-prefix}-refined"
}

resource "aws_s3_bucket" "resources_bucket" {
    bucket = "${var.resource-prefix}-resources"
}