resource "aws_sns_topic" "quality_sns" {
    name = "${var.resource-prefix}-quality-sns"
}

resource "aws_sns_topic_subscription" "quality_sns_subscription" {
    endpoint  = "email@email.com"
    protocol  = "email"
    topic_arn = aws_sns_topic.quality_sns.arn
}