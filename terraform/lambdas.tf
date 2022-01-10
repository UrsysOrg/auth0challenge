# Create role for evaluate_instance, lock_instance, stop_instance

### IAM

# EVALUATE LAMBDA
# Requires permission to read EC2, manage SQS, publish to logs
resource "aws_iam_role" "evaluate_lambda_role" {
  name = "evaluate_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "evaluate_lambda_policy" {
    name = "evaluate_lambda_policy"
    path = "/"
    description = "IAM policy for evaluate lambda function. Grants read to EC2, manage SQS, publish to logs"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = [
            "ec2:Describe*",
            ]
            Effect   = "Allow"
            Resource = "*"
        },
        {
            "Effect": "Allow",
            "Action": "elasticloadbalancing:Describe*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:Describe*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "autoscaling:Describe*",
            "Resource": "*"
        },        
        {
            Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            ]
            Effect   = "Allow"
            Resource = "*"
        },
        {
            Action = [
            "sqs:SendMessage",
            "sqs:GetQueueAttributes",
            "sqs:GetQueueUrl",
            "sqs:GetQueueAttributes",
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            ]
            Effect   = "Allow"
            Resource = "*"
        },
        ]
    })
}

# We use iam_policy_attachment because we want this to be an exclusive attachment of policy to role
resource "aws_iam_policy_attachment" "evaluate_lambda_policy_attachment" {
    name = "evaluate_lambda_policy_attachment"
    roles       = [aws_iam_role.evaluate_lambda_role.name]
    policy_arn = "${aws_iam_policy.evaluate_lambda_policy.arn}"
}

# STOP/LOCK LAMBDAS

resource "aws_iam_role" "stop_lock_lambda_role" {
  name = "stop_lock_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "stop_lock_lambda_policy" {
    name = "iam_policy_for_stop_lock_lambda"
    path = "/"
    description = "IAM policy for stop/lock lambda function. Grants write to EC2, manage SQS, publish to logs"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = [
            "ec2:*",
            ]
            Effect   = "Allow"
            Resource = "*"
        },
        {
            "Effect": "Allow",
            "Action": "elasticloadbalancing:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:*",
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "autoscaling:*",
            "Resource": "*"
        },        
        {
            Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            ]
            Effect   = "Allow"
            Resource = "*"
        },
        {
            Action = [
            "sqs:SendMessage",
            "sqs:GetQueueAttributes",
            "sqs:GetQueueUrl",
            "sqs:GetQueueAttributes",
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            ]
            Effect   = "Allow"
            Resource = "*"
        },
        ]
    })
}

resource "aws_iam_policy_attachment" "stop_lock_lambda_policy_attachment" {
    name = "stop_lock_lambda_policy_attachment"
    roles       = [aws_iam_role.stop_lock_lambda_role.name]
    policy_arn = "${aws_iam_policy.stop_lock_lambda_policy.arn}"
}

### GET LATEST LAMBDA IMAGES

data "aws_ecr_image" "evaluate_image" {
    repository_name = aws_ecr_repository.evaluate_repository.name
    image_tag = "latest"
}

data "aws_ecr_image" "lock_image" {
    repository_name = aws_ecr_repository.lock_repository.name
    image_tag = "latest"
}
data "aws_ecr_image" "stop_image" {
    repository_name = aws_ecr_repository.stop_repository.name
    image_tag = "latest"
}

# For evaluate_instance:

resource "aws_lambda_function" "evaluate_instances" {
    function_name = "evaluate_instances"
    role = aws_iam_role.evaluate_lambda_role.arn
    description = "Evaluate instances for problematic security groups. If found, lock or stop the group as appropriate."
    timeout = "10"
    package_type = "Image"
    image_uri = "${aws_ecr_repository.evaluate_repository.repository_url}@${data.aws_ecr_image.evaluate_image.image_digest}"
    memory_size = "128"
    publish = true
    dead_letter_config {
        target_arn = aws_sqs_queue.get_instance_info_dl_queue.arn
    }
}

resource "aws_lambda_event_source_mapping" "evaluate_instances" {
    event_source_arn = aws_sqs_queue.get_instance_info_queue.arn
    function_name = aws_lambda_function.evaluate_instances.arn
    batch_size = 0
    enabled = true
    maximum_batching_window_in_seconds = 0
}


# For lock_instance:
# Permission to write to logs, send and recieve from queues, describe EC2 security groups, create EC2 security groups + rules, attach security groups to EC2 instances
resource "aws_lambda_function" "lock_instance" {
    function_name = "lock_instance"
    role = aws_iam_role.stop_lock_lambda_role.arn
    description = "Stops EC2 instances flagged by evaluate_instances."
    timeout = "10"
    package_type = "Image"
    image_uri = "${aws_ecr_repository.lock_repository.repository_url}@${data.aws_ecr_image.lock_image.image_digest}"
    memory_size = "128"
    publish = true
    dead_letter_config {
        target_arn = aws_sqs_queue.lock_instance_dl_queue.arn
    }
}

resource "aws_lambda_event_source_mapping" "lock_instance" {
    event_source_arn = aws_sqs_queue.lock_instance_queue.arn
    function_name = aws_lambda_function.lock_instance.arn
    batch_size = 0
    enabled = true
    maximum_batching_window_in_seconds = 0
}


# For stop_instance:
# Permission to write to logs, send and recieve from queues, describe EC2 instances, stop EC2 instances
resource "aws_lambda_function" "stop_instance" {
    function_name = "stop_instance"
    role = aws_iam_role.stop_lock_lambda_role.arn
    description = "Locks EC2 instances by removing bad security groups, when flagged from evaluate_instances."
    timeout = "10"
    package_type = "Image"
    image_uri = "${aws_ecr_repository.stop_repository.repository_url}@${data.aws_ecr_image.stop_image.image_digest}"
    memory_size = "128"
    publish = true
    dead_letter_config {
        target_arn = aws_sqs_queue.stop_instance_dl_queue.arn
    }
}

resource "aws_lambda_event_source_mapping" "stop_instance" {
    event_source_arn = aws_sqs_queue.stop_instance_queue.arn
    function_name = aws_lambda_function.stop_instance.arn
    batch_size = 0
    enabled = true
    maximum_batching_window_in_seconds = 0
}