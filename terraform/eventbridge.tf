resource "aws_cloudwatch_event_bus" "ec2_shutdown_bus" {
  name = "ec2-shutdown-bus"
}

### IAM

# Creates a new role which we will attach all remote cloudwatch event targets to
resource "aws_iam_role" "assume_send_events_role" {
  name               = "assume-send-events-role"
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


# Creates a policy document that allows PutEvents to our destination eventbus
data "aws_iam_policy_document" "put_events_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = ["arn:aws:events:us-east-1:${var.account_id}:event-bus/ec2-shutdown-bus"]
  }
}

# Creates a policy with the above policy document 
resource "aws_iam_policy" "put_events_policy" {
  name        = "event-bus-invoke-remote-event-bus"
  description = "event-bus-invoke-remote-event-bus"
  policy      = data.aws_iam_policy_document.put_events_policy_document.json
}

# Attachs the above policy to the role
resource "aws_iam_role_policy_attachment" "event_bus_invoke_remote_event_bus_policy_attachment" {
  role       = aws_iam_role.assume_send_events_role.name
  policy_arn = aws_iam_policy.put_events_policy.arn
}

# Creates a policy document that will attach to our destination event bus, allowing access only from entites with the assume-send-events-role
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
      identifiers = ["${aws_iam_role.assume_send_events_role.arn}"]
    }
  }
}

# Attachs our resource based policy to our destination event bus
resource "aws_cloudwatch_event_bus_policy" "allow_multiregion_events_policy" {
  # AWS automatically changes the ARN to the role unique principal ID when you save the policy, see: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_principal.html#principal-roles
  # We can ignore changes to this on plan.
  event_bus_name = aws_cloudwatch_event_bus.ec2_shutdown_bus.name
  policy         = data.aws_iam_policy_document.allow_multiregion_resource_policy.json
}


### DESTINATION EVENT RULE

# This rule processes all EC2 state change events
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

# We then send all events to SQS, transforming the event input to obtain only the information we really need
resource "aws_cloudwatch_event_target" "sqs" {
  rule           = aws_cloudwatch_event_rule.instance_id.name
  target_id      = "SendToSQS"
  arn            = aws_sqs_queue.get_instance_info_queue.arn
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
