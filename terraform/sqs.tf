resource "aws_sqs_queue" "quality_sqs" {
    name = "${var.resource-prefix}-quality-sqs"
    visibility_timeout_seconds = 300
}

resource "aws_sqs_queue" "processing_sqs" {
    name = "${var.resource-prefix}-processing-sqs"
    visibility_timeout_seconds = 300
}