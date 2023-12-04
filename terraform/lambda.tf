variable "account_id" {}

variable "config_bucket" {}
variable "gx_path" {}
variable "config_path" {}
variable "aws_resources_bucket" {}

### Data Quality Lambda
resource "aws_lambda_function" "quality_function" {
  function_name = "${var.resource-prefix}-quality"
  role          = aws_iam_role.quality_lambda_role.arn
  image_uri = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.resource-prefix}-dataquality:latest"
  package_type = "Image"
  architectures = ["x86_64"]
  timeout = 300
  memory_size = 256
  environment {
    variables = {
      CONFIG_BUCKET = var.config_bucket
      CONFIG_PATH = var.config_path
      AWS_RESOURCES_BUCKET = var.aws_resources_bucket
      GX_PATH = var.gx_path
      QUEUE_NAME = aws_sqs_queue.quality_sqs.name
      SNS_TOPIC_ARN = aws_sns_topic.quality_sns.arn
    }
  }
}

resource "aws_lambda_permission" "quality_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.quality_function.function_name
  principal     = "s3.amazonaws.com"
  depends_on = [aws_lambda_function.quality_function]
}

resource "aws_s3_bucket_notification" "quality_trigger" {
  bucket = "${var.resource-prefix}-raw"
  lambda_function {
      lambda_function_arn = aws_lambda_function.quality_function.arn
      events              = ["s3:ObjectCreated:*"]
      filter_prefix       = ""
  }
  depends_on = [aws_lambda_permission.quality_lambda_permission]
}