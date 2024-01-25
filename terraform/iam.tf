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
                        aws_sqs_queue.quality_sqs.arn,
                        aws_sqs_queue.processing_sqs.arn
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

resource "aws_iam_policy" "glue_etl_policy" {
    policy = jsonencode(
        {
            "Version": "2012-10-17",
            "Statement": [
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
                    "Action": [
                        "s3:Get*",
                        "s3:Put*",
                        "s3:Delete*",
                        "s3:List*",
                    ],
                    "Resource": [
                        "arn:aws:s3:::${var.resource-prefix}-trusted",
                        "arn:aws:s3:::${var.resource-prefix}-trusted/*",
                        "arn:aws:s3:::${var.resource-prefix}-refined",
                        "arn:aws:s3:::${var.resource-prefix}-refined/*",
                        "arn:aws:s3:::${var.resource-prefix}-raw",
                        "arn:aws:s3:::${var.resource-prefix}-raw/*",
                        "arn:aws:s3:::${var.resource-prefix}-resources",
                        "arn:aws:s3:::${var.resource-prefix}-resources/*"
                    ],
                    "Effect": "Allow"
                },
                {
                    "Action": [
                        "glue:Get*",
                        "glue:Create*",
                        "glue:Update*",
                        "glue:Delete*",
                        "glue:Batch*"
                    ],
                    "Resource": "*",
                    "Effect": "Allow"
                }
            ]
        }
    )
}

resource "aws_iam_role" "glue_etl_role" {
    assume_role_policy = jsonencode(
        {
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
        }
    )
}

resource "aws_iam_role_policy_attachment" "glue_etl_policy_attachment" {
    role       = aws_iam_role.glue_etl_role.name
    policy_arn = aws_iam_policy.glue_etl_policy.arn
}

resource "aws_iam_role" "process_lambda_role" {
    name               = "${var.resource-prefix}-process-lambda-role"
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

resource "aws_iam_policy" "process_lambda_policy" {
    name        = "${var.resource-prefix}-process-lambda-policy"
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
                        "glue:GetJob",
                        "glue:GetJobs",
                        "glue:GetJobRun",
                        "glue:ListJobs",
                        "glue:BatchStopJobRun",
                        "glue:StartJobRun",
                        "glue:BatchGetJobs",
                        "glue:GetJobRuns",
                    ],
                    "Resource": "*"
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
                        aws_sqs_queue.processing_sqs.arn
                    ]
                }
            ]
        }
    )
}

resource "aws_iam_role_policy_attachment" "process_lambda_policy_attachment" {
    role       = aws_iam_role.process_lambda_role.name
    policy_arn = aws_iam_policy.process_lambda_policy.arn
}

resource "aws_iam_role" "beanstalk_role" {
    name               = "${var.resource-prefix}-beanstalk-role"
    assume_role_policy = jsonencode(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "sts:AssumeRole",
                    "Principal": {
                        "Service": "ec2.amazonaws.com"
                    },
                    "Effect": "Allow",
                    "Sid": ""
                }
            ]
        }
    )
}

resource "aws_iam_policy" "beanstalk_policy" {
    name = "${var.resource-prefix}-beanstalk-policy"
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
                        "arn:aws:s3:::${var.resource-prefix}-resources/*",
                        "arn:aws:s3:::aws-athena-query-results-${var.account_id}-${var.region}",
                        "arn:aws:s3:::aws-athena-query-results-${var.account_id}-${var.region}/*"
                    ]
                },
                {
                    "Effect" : "Allow",
                    "Action" : [
                        "s3:GetBucketLocation",
                    ],
                    "Resource" : [
                        "arn:aws:s3:::*"
                    ]
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "ecr:BatchCheckLayerAvailability",
                        "ecr:GetDownloadUrlForLayer",
                        "ecr:BatchGetImage",
                        "ecr:GetAuthorizationToken",
                        "ecr:GetRepositoryPolicy",
                        "ecr:DescribeRepositories",
                        "ecr:ListImages",
                        "ecr:DescribeImages"
                    ],
                    "Resource": "*"
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "athena:StartQueryExecution",
                        "athena:GetQueryExecution",
                        "athena:GetQueryResults",
                        "athena:StopQueryExecution",
                        "athena:GetWorkGroup",
                        "athena:ListWorkGroups",
                        "athena:ListQueryExecutions",
                        "athena:ListNamedQueries"
                    ],
                    "Resource": "*"
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "glue:GetDatabase",
                        "glue:GetDatabases",
                        "glue:GetTable",
                        "glue:GetTables",
                        "glue:GetPartitions",
                        "glue:GetPartition",
                        "glue:BatchGetPartition"
                    ],
                    "Resource": "*"
                }
            ]
        }
    )
}

resource "aws_iam_role_policy_attachment" "beanstalk_log_attach" {
  role       = aws_iam_role.beanstalk_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "beanstalk_policy_attach" {
    policy_arn = aws_iam_policy.beanstalk_policy.arn
    role       = aws_iam_role.beanstalk_role.name
}

resource "aws_iam_instance_profile" "beanstalk_iam_instance_profile" {
  name = "geekfox-pawprint-beanstalk-instance-profile"
  role = aws_iam_role.beanstalk_role.name
}