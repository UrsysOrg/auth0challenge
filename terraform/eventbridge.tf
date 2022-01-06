resource "aws_cloudwatch_event_rule" "instance_id" {
  name        = "capture-instance-id"
  description = "Capture each Running Instance's ID"
  tags = {
    Candidate = "Sara Angel-Murphy"
  }

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "sqs" {
  rule      = aws_cloudwatch_event_rule.instance_id.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.get_instance_info_queue.arn
  retry_policy {
    maximum_retry_attempts       = "2"
    maximum_event_age_in_seconds = "600"
  }
  dead_letter_config {
    arn = aws_sqs_queue.get_instance_info_dl_queue.arn
  }
  input_transformer {
    input_paths = {
      instance = "$.detail.instance-id"
      region   = "$.region"
    }
    input_template = <<EOF
{
  "instance_id": <instance>
}
EOF
  }

}

