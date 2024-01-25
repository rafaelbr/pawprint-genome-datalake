resource "aws_elastic_beanstalk_application" "search_streamlit" {
  name        = "${var.resource-prefix}-search-streamlit"
  description = "Data Search"
}

resource "aws_elastic_beanstalk_environment" "prd_env" {
  name         = "${var.resource-prefix}-search-streamlit-prd"
  application  = aws_elastic_beanstalk_application.search_streamlit.name
  cname_prefix = "${var.resource-prefix}-search-streamlit"

  solution_stack_name = "64bit Amazon Linux 2023 v4.1.2 running Docker"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.beanstalk_iam_instance_profile.arn
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "True"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.main.id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "${aws_subnet.public_subnet_1a.id}, ${aws_subnet.public_subnet_1b.id}"
  }

  setting {
    namespace = "aws:elb:listener"
    name      = "ListenerProtocol"
    value     = "TCP"
  }


  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     =  "True"
  }
}

resource "aws_elastic_beanstalk_application_version" "beanstalk_app_version" {
  name        = "${var.resource-prefix}-search-streamlit"
  application = aws_elastic_beanstalk_application.search_streamlit.name
  description = "application version created by terraform"
  bucket      = aws_s3_bucket.resources_bucket.id
  key         = "search/Dockerrun.aws.json"
}
