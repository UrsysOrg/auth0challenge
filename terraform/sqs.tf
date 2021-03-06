### US EAST 1
locals {
  testarn = "arn:aws:lambda:us-east-1:201973737062:function:helloWorldTestEc2"
  stoparn = "arn:aws:lambda:us-east-1:201973737062:function:stopTest"
}
resource "aws_sqs_queue" "get_instance_info_queue" {
  name                       = "get_instance_info_queue"
  delay_seconds              = 0       # We don't need any delays here
  max_message_size           = 262144  # 256k
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 0       # Time ReceiveMessage should wait for a message to arrive
  visibility_timeout_seconds = 30      # Time in seconds that messages consumed are hidden from other consumers. Adjust depending on average lambda processing time.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.get_instance_info_dl_queue.arn
    maxReceiveCount     = 4
  })
}
resource "aws_sqs_queue_policy" "get_instance_info_queue_policy" {
  queue_url = aws_sqs_queue.get_instance_info_queue.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.get_instance_info_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_cloudwatch_event_rule.instance_id.arn}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_sqs_queue" "get_instance_info_dl_queue" {
  name = "get_instance_info_dl_queue"
}

resource "aws_sqs_queue_policy" "get_instance_info_dl_queue_policy" {
  queue_url = aws_sqs_queue.get_instance_info_dl_queue.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.get_instance_info_dl_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_cloudwatch_event_rule.instance_id.arn}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_sqs_queue" "stop_instance_queue" {
  name                       = "stop_instance_queue"
  delay_seconds              = 0       # We want to avoid any delays
  max_message_size           = 262144  # 256k
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 0       # Time ReceiveMessage should wait for a message to arrive
  visibility_timeout_seconds = 30      # Time in seconds that messages consumed are hidden from other consumers. Adjust depending on average lambda processing time.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.stop_instance_dl_queue.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue_policy" "stop_instance_queue_policy" {
  queue_url = aws_sqs_queue.stop_instance_queue.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.stop_instance_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${local.testarn}"
        }
      }
    }
  ]
}
POLICY
}


resource "aws_sqs_queue" "stop_instance_dl_queue" {
  name = "stop_instance_dl_queue"
}

resource "aws_sqs_queue_policy" "stop_instance_dl_queue_policy" {
  queue_url = aws_sqs_queue.stop_instance_dl_queue.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.stop_instance_dl_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${local.testarn}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_sqs_queue" "lock_instance_queue" {
  name                       = "lock_instance_queue"
  delay_seconds              = 0       # We want to avoid any delays
  max_message_size           = 262144  # 256k
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 0       # Time ReceiveMessage should wait for a message to arrive
  visibility_timeout_seconds = 30      # Time in seconds that messages consumed are hidden from other consumers. Adjust depending on average lambda processing time.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.lock_instance_dl_queue.arn
    maxReceiveCount     = 4
  })
}
resource "aws_sqs_queue_policy" "lock_instance_queue_policy" {
  queue_url = aws_sqs_queue.lock_instance_queue.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.lock_instance_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": ["${local.testarn}", "${local.stoparn}"]
        }
      }
    }
  ]
}
POLICY
}

resource "aws_sqs_queue" "lock_instance_dl_queue" {
  name = "lock_instance_dl_queue"
}
resource "aws_sqs_queue_policy" "lock_instance_dl_queue_policy" {
  queue_url = aws_sqs_queue.lock_instance_dl_queue.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.lock_instance_dl_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_cloudwatch_event_rule.instance_id.arn}"
        }
      }
    }
  ]
}
POLICY
}
