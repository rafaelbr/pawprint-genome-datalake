# Required resources roles and policies
resource "aws_iam_policy" "glue_crawler_policy" {
    name        = "${var.resource-prefix}-glue-crawler-policy"
    description = "Policy for Glue crawlers"
    policy      = jsonencode(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                  "Effect": "Allow",
                  "Action": [
                      "s3:GetObject",
                      "s3:PutObject"
                  ],
                  "Resource": [
                    "arn:aws:s3:::${var.resource-prefix}-trusted/*",
                    "arn:aws:s3:::${var.resource-prefix}-refined/*"
                  ]
                }
            ]
        }
    )
}

resource "aws_iam_role" "glue_crawler_role" {
    name               = "${var.resource-prefix}-glue-crawler-role"
    assume_role_policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                    "Service": "glue.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "crawler_policy_attachment" {
    role       = aws_iam_role.glue_crawler_role.name
    policy_arn = aws_iam_policy.glue_crawler_policy.arn
}

resource "aws_iam_role" "quality_lambda_role" {
    name               = "${var.resource-prefix}-quality-lambda-role"
    assume_role_policy = jsonencode(
        {
            "Version" : "2012-10-17",
            "Statement" : [
                {
                    "Effect" : "Allow",
                    "Action" : "sts:AssumeRole",
                    "Principal" : {
                        "Service" : "lambda.amazonaws.com"
                    }
                }
            ]
        }
    )
}

resource "aws_iam_policy" "quality_lambda_policy" {
    name        = "${var.resource-prefix}-quality-lambda-policy"
    policy = jsonencode(
        {
            "Version" : "2012-10-17",
            "Statement" : [
                {
                    "Effect" : "Allow",
                    "Action" : [
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents"
                    ],
                    "Resource" : "arn:aws:logs:*:*:*"
                },
                {
                    "Effect" : "Allow",
                    "Action" : [
                        "s3:PutObject",
                        "s3:GetObject",
                        "s3:DeleteObject",
                        "s3:ListBucket"
                    ],
                    "Resource" : [
                        "arn:aws:s3:::${var.resource-prefix}-raw",
                        "arn:aws:s3:::${var.resource-prefix}-raw/*",
                        "arn:aws:s3:::${var.resource-prefix}-trusted",
                        "arn:aws:s3:::${var.resource-prefix}-trusted/*",
                        "arn:aws:s3:::${var.resource-prefix}-resources",
                        "arn:aws:s3:::${var.resource-prefix}-resources/*"
                    ]
                },
                {
                    "Effect" : "Allow",
                    "Action": [
                        "sns:Publish"
                    ],
                    "Resource": [
                        aws_sns_topic.quality_sns.arn
                    ]
                },
                {
                    "Effect" : "Allow",
                    "Action": [
                        "sqs:DeleteMessage",
                        "sqs:GetQueueUrl",
                        "sqs:ListQueues",
                        "sqs:ChangeMessageVisibility",
                        "sqs:SendMessageBatch",
                        "sqs:ReceiveMessage",
                        "sqs:SendMessage",
                        "sqs:GetQueueAttributes",
                        "sqs:ListQueueTags",
                        "sqs:ListDeadLetterSourceQueues",
                        "sqs:DeleteMessageBatch",
                        "sqs:ChangeMessageVisibilityBatch",
                        "sqs:SetQueueAttributes"
                    ],
                    "Resource": [
                        aws_sqs_queue.quality_sqs.arn
                    ]
                }
            ]
        }
    )
}

resource "aws_iam_role_policy_attachment" "quality_lambda_policy_attachment" {
    role       = aws_iam_role.quality_lambda_role.name
    policy_arn = aws_iam_policy.quality_lambda_policy.arn
}