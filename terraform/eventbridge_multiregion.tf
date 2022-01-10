### MULTI-REGION EVENTBRIDGE CONFIGURATION

# To add additional regions, copy and paste and change:
# provider name, resource name, event target rule
# Terraform does not allow iterating over providers because it associates resources with providers prior to all other processing
# There is a for_each in the provider configuration reserved for a future use of terraform

### US WEST 1

resource "aws_cloudwatch_event_rule" "capture_ec2_remote_us_west" {
  provider    = aws.uswest1
  name        = "capture-ec2-remote"
  description = "Capture each Running EC2 instance and sends the event unmodified to remote event bus"
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
resource "aws_cloudwatch_event_target" "send_to_remote_sa_east_1" {
  provider  = aws.saeast1
  target_id = "SendToRemoteBus"
  arn       = aws_cloudwatch_event_bus.ec2_shutdown_bus.arn
  role_arn  = aws_iam_role.assume_send_events_role.arn
  rule      = aws_cloudwatch_event_rule.capture_ec2_remote_sa_east_1.name
}