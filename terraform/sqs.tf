resource "aws_sqs_queue" "get_instance_info_queue" {
  name                      = "get_instance_info_queue"
  delay_seconds             = 0 # We want to avoid any delays
  max_message_size          = 262144 # 256k
  message_retention_seconds = 1209600 # 14 days
  receive_wait_time_seconds = 0 # Time ReceiveMessage should wait for a message to arrive
  visibility_timeout_seconds = 30 # Time in seconds that messages consumed are hidden from other consumers. Adjust depending on average lambda processing time.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.get_instance_info_dl_queue.arn
    maxReceiveCount     = 4
  })

  tags = {
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_sqs_queue" "get_instance_info_dl_queue" {
  name                      = "get_instance_info_dl_queue"
  tags = {
    Environment = "Sara Angel-Murphy"
  }
}

resource "aws_sqs_queue" "stop_instance_queue" {
  name                      = "stop_instance_queue"
  delay_seconds             = 0 # We want to avoid any delays
  max_message_size          = 262144 # 256k
  message_retention_seconds = 1209600 # 14 days
  receive_wait_time_seconds = 0 # Time ReceiveMessage should wait for a message to arrive
  visibility_timeout_seconds = 30 # Time in seconds that messages consumed are hidden from other consumers. Adjust depending on average lambda processing time.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.get_instance_info_dl_queue.arn
    maxReceiveCount     = 4
  })

  tags = {
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_sqs_queue" "stop_instance_dl_queue" {
  name                      = "stop_instance_dl_queue"
  tags = {
    Environment = "Sara Angel-Murphy"
  }
}

resource "aws_sqs_queue" "terminate_instance_queue" {
  name                      = "terminate_instance_queue"
  delay_seconds             = 0 # We want to avoid any delays
  max_message_size          = 262144 # 256k
  message_retention_seconds = 1209600 # 14 days
  receive_wait_time_seconds = 0 # Time ReceiveMessage should wait for a message to arrive
  visibility_timeout_seconds = 30 # Time in seconds that messages consumed are hidden from other consumers. Adjust depending on average lambda processing time.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.get_instance_info_dl_queue.arn
    maxReceiveCount     = 4
  })

  tags = {
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_sqs_queue" "terminate_instance_dl_queue" {
  name                      = "terminate_instance_dl_queue"
  tags = {
    Environment = "Sara Angel-Murphy"
  }
}

resource "aws_sqs_queue" "lock_instance_queue" {
  name                      = "lock_instance_queue"
  delay_seconds             = 0 # We want to avoid any delays
  max_message_size          = 262144 # 256k
  message_retention_seconds = 1209600 # 14 days
  receive_wait_time_seconds = 0 # Time ReceiveMessage should wait for a message to arrive
  visibility_timeout_seconds = 30 # Time in seconds that messages consumed are hidden from other consumers. Adjust depending on average lambda processing time.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.get_instance_info_dl_queue.arn
    maxReceiveCount     = 4
  })

  tags = {
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_sqs_queue" "lock_instance_dl_queue" {
  name                      = "lock_instance_dl_queue"
  tags = {
    Environment = "Sara Angel-Murphy"
  }
}
