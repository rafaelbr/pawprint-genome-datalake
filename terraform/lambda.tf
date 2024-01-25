variable "account_id" {}

variable "config_bucket" {}
variable "gx_path" {}
variable "config_path" {}
variable "aws_resources_bucket" {}

### Data Quality Lambda
resource "aws_lambda_function" "data_quality_function" {
  function_name = "${var.resource-prefix}-data-quality"
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

resource "aws_lambda_permission" "data_quality_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_quality_function.function_name
  principal     = "s3.amazonaws.com"
  depends_on = [aws_lambda_function.data_quality_function]
}

resource "aws_s3_bucket_notification" "data_quality_lambda_trigger" {
  bucket = "${var.resource-prefix}-raw"
  lambda_function {
      lambda_function_arn = aws_lambda_function.data_quality_function.arn
      events              = ["s3:ObjectCreated:*"]
      filter_prefix       = ""
  }
  depends_on = [aws_lambda_permission.data_quality_lambda_permission]
}

data "archive_file" "schema_conformity" {
  type        = "zip"
  output_path = "schema_conformity.zip"
  source {
    filename = "app.py"
    content = file("${path.module}/../src/quality/schema_conformity.py")
  }
}

resource "aws_lambda_function" "schema_conformity_lambda" {
    function_name = "${var.resource-prefix}-schema-conformity-lambda"
    role          = aws_iam_role.quality_lambda_role.arn
    filename = "schema_conformity.zip"
    handler = "app.lambda_handler"
    layers = [aws_lambda_layer_version.json_handle_layer.arn]
    source_code_hash = data.archive_file.schema_conformity.output_base64sha256
    runtime = "python3.9"
    timeout = 300
    memory_size = 256
    environment {
      variables = {
        CONFIG_BUCKET = var.config_bucket
        CONFIG_PATH = var.config_path
        AWS_RESOURCES_BUCKET = var.aws_resources_bucket
        QUEUE_NAME = aws_sqs_queue.processing_sqs.name
      }
    }
}

resource "aws_lambda_permission" "schema_conformity_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.schema_conformity_lambda.function_name
  principal     = "s3.amazonaws.com"
  depends_on = [aws_lambda_function.schema_conformity_lambda]
}

resource "aws_lambda_event_source_mapping" "schema_trigger" {
    event_source_arn = aws_sqs_queue.quality_sqs.arn
    function_name = aws_lambda_function.schema_conformity_lambda.function_name
    depends_on = [aws_sqs_queue.quality_sqs]
}

data "archive_file" "data_process" {
  type        = "zip"
  output_path = "data_process.zip"
  source {
    filename = "app.py"
    content = file("${path.module}/../src/processing/lambda/process_trusted.py")
  }
}

resource "aws_lambda_function" "data_process_lambda" {
    function_name = "${var.resource-prefix}-process-lambda"
    role          = aws_iam_role.process_lambda_role.arn
    filename = "data_process.zip"
    handler = "app.lambda_handler"
    source_code_hash = data.archive_file.data_process.output_base64sha256
    runtime = "python3.9"
    timeout = 300
    memory_size = 256
}

resource "aws_lambda_event_source_mapping" "process_trigger" {
    event_source_arn = aws_sqs_queue.processing_sqs.arn
    function_name = aws_lambda_function.data_process_lambda.function_name
    depends_on = [aws_sqs_queue.quality_sqs]
}


resource "aws_lambda_layer_version" "json_handle_layer" {
  layer_name = "${var.resource-prefix}-json-handle-layer"
  filename = "../lambda-layers/json_handle.zip"
}