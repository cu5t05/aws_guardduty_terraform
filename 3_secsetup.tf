# -----------------------------
# Caller Identity (for account ID)
# -----------------------------
data "aws_caller_identity" "current" {}

# -----------------------------
# CloudTrail Bucket Policy
# -----------------------------
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.lab_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck",
        Effect    = "Allow",
        Principal = { Service = "cloudtrail.amazonaws.com" },
        Action    = "s3:GetBucketAcl",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.lab_bucket.bucket}"
      },
      {
        Sid       = "AWSCloudTrailWrite",
        Effect    = "Allow",
        Principal = { Service = "cloudtrail.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.lab_bucket.bucket}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# -----------------------------
# CloudTrail Setup
# -----------------------------
resource "aws_cloudtrail" "gd_lab_trail" {
  name                          = "gd-lab-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.lab_bucket.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  depends_on = [
    aws_s3_bucket_policy.cloudtrail_bucket_policy
  ]
}

# -----------------------------
# GuardDuty Setup
# -----------------------------
resource "aws_guardduty_detector" "lab" {
  enable                        = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_threatintelset" "lab_threat_list" {
  detector_id = aws_guardduty_detector.lab.id
  name        = "lab-threat-list"
  format      = "TXT"
  location    = "https://${aws_s3_bucket.lab_bucket.bucket}.s3.amazonaws.com/threatlist.txt"
  activate    = true
}

# -----------------------------
# Security Hub Setup
# -----------------------------
resource "aws_securityhub_account" "lab" {
  depends_on = [aws_guardduty_detector.lab]
}

# -----------------------------
# SNS Notification Setup
# -----------------------------
resource "aws_sns_topic" "gd_lab_alerts" {
  name = "gd-lab-alerts"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.gd_lab_alerts.arn
  protocol  = "email"
  endpoint  = "put@your.email"  # Replace with your actual email
}

resource "aws_sns_topic_policy" "gd_lab_alerts_policy" {
  arn = aws_sns_topic.gd_lab_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "AllowEventBridgeToPublish",
        Effect: "Allow",
        Principal: {
          Service: "events.amazonaws.com"
        },
        Action: "sns:Publish",
        Resource: aws_sns_topic.gd_lab_alerts.arn
      }
    ]
  })
}

# -----------------------------
# EventBridge Rules and Targets
# -----------------------------
resource "aws_cloudwatch_event_rule" "guardduty_to_sns" {
  name        = "gd-direct-to-sns"
  description = "Send all GuardDuty events to SNS"
  event_pattern = jsonencode({
    "source": ["aws.guardduty"]
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sns_target" {
  rule      = aws_cloudwatch_event_rule.guardduty_to_sns.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.gd_lab_alerts.arn
}

resource "aws_cloudwatch_event_rule" "gd_event" {
  name        = "gd-guardduty-rule"
  description = "Triggers Lambda on GuardDuty findings"
  event_pattern = jsonencode({
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"]
  })
}

resource "aws_cloudwatch_event_target" "gd_lambda_trigger" {
  rule      = aws_cloudwatch_event_rule.gd_event.name
  target_id = "gd-stop-instance"
  arn       = aws_lambda_function.gd_stop_instance.arn
}

# -----------------------------
# Lambda Function and Permissions
# -----------------------------
resource "aws_lambda_function" "gd_stop_instance" {
  function_name = "gd-stop-compromised-instance"
  role          = aws_iam_role.gd_lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 10

  filename         = "${path.module}/gd_lambda_payload.zip"
  source_code_hash = filebase64sha256("${path.module}/gd_lambda_payload.zip")

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }
}

resource "aws_lambda_permission" "gd_lambda_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gd_stop_instance.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.gd_event.arn
}

# -----------------------------
# IAM Roles and Attachments
# -----------------------------
resource "aws_iam_role" "gd_lambda_role" {
  name = "gd-lab-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.gd_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_ec2" {
  role       = aws_iam_role.gd_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role" "vpc_flow_log_role" {
  name = "gd-vpc-flow-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_flow_log_attach" {
  role       = aws_iam_role.vpc_flow_log_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# -----------------------------
# VPC Flow Logs (referencing existing VPC)
# -----------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  name              = "/gd/lab/vpcflow"
  retention_in_days = 7
}

resource "aws_flow_log" "lab_vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_log_group.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.lab.id
  iam_role_arn         = aws_iam_role.vpc_flow_log_role.arn
}
