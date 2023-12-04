resource "aws_sqs_queue" "quality_sqs" {
    name = "${var.resource-prefix}-quality-sqs"
}