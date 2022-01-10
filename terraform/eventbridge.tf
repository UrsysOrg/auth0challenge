resource "aws_cloudwatch_event_bus" "ec2_shutdown_bus" {
  name = "ec2-shutdown-bus"
}

data "aws_iam_policy_document" "allow_multiregion_resource_policy" {
  statement {
    sid    = "MultiRegionalAccountAccess"
    effect = "Allow"
    actions = [
      "events:PutEvents",
    ]
    resources = [
      "arn:aws:events:eu-west-1:${var.account_id}:event-bus/ec2-shutdown-bus",
    ]

    principals {
      type        = "AWS"
      identifiers = ["${var.account_id}"]
    }
  }
}

resource "aws_cloudwatch_event_bus_policy" "allow_multiregion_events_policy" {
  event_bus_name = "${aws_cloudwatch_event_bus.ec2_shutdown_bus.name}"
  policy = "${data.aws_iam_policy_document.allow_multiregion_resource_policy.json}"
}

resource "aws_cloudwatch_event_rule" "instance_id" {
  name           = "capture-instance-id"
  description    = "Capture each Running Instance's ID"
  event_bus_name = aws_cloudwatch_event_bus.ec2_shutdown_bus.name
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
  event_bus_name = aws_cloudwatch_event_bus.ec2_shutdown_bus.name
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
  "instance_id": "<instance>",
  "region": "<region>"
}
EOF
  }

}

### MULTI-REGION


data "aws_iam_policy_document" "put_events_policy_document_us_west" {
  provider = aws.uswest1
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = ["arn:aws:events:us-east-1:${var.account_id}:event-bus/ec2-shutdown-bus"]
  }
}

resource "aws_iam_role" "assume_send_events_role_us_west" {
  provider    = aws.uswest1
  name = "assume-send-events-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "put_events_policy_us_west" {
  provider    = aws.uswest1
  name        = "event-bus-invoke-remote-event-bus"
  description = "event-bus-invoke-remote-event-bus"
  policy      = data.aws_iam_policy_document.put_events_policy_document_us_west.json
}

resource "aws_iam_role_policy_attachment" "event_bus_invoke_remote_event_bus_policy_attachment_us_west" {
  provider   = aws.uswest1
  role       = aws_iam_role.assume_send_events_role_us_west.name
  policy_arn = aws_iam_policy.put_events_policy_us_west.arn
}

resource "aws_cloudwatch_event_bus" "bus_route_to_remote_us_west" {
  provider = aws.uswest1
  name     = "route-to-remote-bus"
}

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_us_west" {
  provider       = aws.uswest1
  name           = "capture-ec2-remote"
  description    = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"
  event_bus_name = aws_cloudwatch_event_bus.bus_route_to_remote_us_west.name
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

resource "aws_cloudwatch_event_target" "send_to_remote_us_west" {
  event_bus_name = aws_cloudwatch_event_bus.bus_route_to_remote_us_west.name
  provider  = aws.uswest1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role_us_west.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_us_west.name
}