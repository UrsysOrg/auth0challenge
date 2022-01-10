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

### Deliver EC2 State Changes to own event bus
resource "aws_cloudwatch_event_rule" "capture_ec2_remote_us_east" {
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_us_east" {
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_us_east.name
}

### DESTINATION EVENT RULE

# This rule processes all EC2 state change events
resource "aws_cloudwatch_event_rule" "instance_id" {
  name           = "capture-instance-id"
  description    = "Capture each Running Instance's ID"
  event_bus_name = aws_cloudwatch_event_bus.ec2_shutdown_bus.name

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

### MULTI-REGION
# To add additional regions, copy and paste and change:
# provider name, resource name, event target rule
# Terraform does not allow iterating over providers because it associates resources with providers prior to all other processing
# There is a for_each in the provider configuration reserved for a future use of terraform

### US WEST 1

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_us_west" {
  provider    = aws.uswest1
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_us_west" {
  provider  = aws.uswest1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_us_west.name
}

### US EAST 2

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_us_east_2" {
  provider    = aws.useast2
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"


  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_us_east_2" {
  provider  = aws.useast2
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_us_east_2.name
}

### US WEST 2

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_us_west2" {
  provider    = aws.uswest2
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_us_west2" {
  provider  = aws.uswest2
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_us_west2.name
}

### AP SOUTH 1

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_ap_south_1" {
  provider    = aws.apsouth1
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_ap_south_1" {
  provider  = aws.apsouth1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_ap_south_1.name
}

### AP SOUTHEAST 1

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_ap_southeast_1" {
  provider    = aws.apsoutheast1
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_ap_southeast_1" {
  provider  = aws.apsoutheast1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_ap_southeast_1.name
}

### AP SOUTHEAST 2

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_ap_southeast_2" {
  provider    = aws.apsoutheast2
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_ap_southeast_2" {
  provider  = aws.apsoutheast2
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_ap_southeast_2.name
}

### AP NORTHEAST 1

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_ap_northeast_1" {
  provider    = aws.apnortheast1
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_ap_northeast_1" {
  provider  = aws.apnortheast1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_ap_northeast_1.name
}

### AP NORTHEAST 2

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_ap_northeast_2" {
  provider    = aws.apnortheast2
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_ap_northeast_2" {
  provider  = aws.apnortheast2
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_ap_northeast_2.name
}

### AP NORTHEAST 3

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_ap_northeast_3" {
  provider    = aws.apnortheast3
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_ap_northeast_3" {
  provider  = aws.apnortheast3
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_ap_northeast_3.name
}

### CA CENTRAL 1

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_ca_central_1" {
  provider    = aws.cacentral1
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_ca_central_1" {
  provider  = aws.cacentral1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_ca_central_1.name
}

### EU CENTRAL 1

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_eu_central_1" {
  provider    = aws.eucentral1
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_eu_central_1" {
  provider  = aws.eucentral1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_eu_central_1.name
}

### EU WEST 1

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_eu_west_1" {
  provider    = aws.euwest1
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_eu_west_1" {
  provider  = aws.euwest1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_eu_west_1.name
}

### EU WEST 2

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_eu_west_2" {
  provider    = aws.euwest2
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"
  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_eu_west_2" {
  provider  = aws.euwest2
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_eu_west_2.name
}

### EU WEST 3

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_eu_west_3" {
  provider    = aws.euwest3
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_eu_west_3" {
  provider  = aws.euwest3
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_eu_west_3.name
}

# EU NORTH 1

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_eu_north_1" {
  provider    = aws.eunorth1
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"
  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_to_remote_eu_north_1" {
  provider  = aws.eunorth1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_eu_north_1.name
}

# SA EAST 1

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_sa_east_1" {
  provider    = aws.saeast1
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}
resource "aws_cloudwatch_event_target" "send_to_remote_sa_east_1" {
  provider  = aws.saeast1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_sa_east_1.name
}