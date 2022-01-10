# Auth0 Challenge Service

This repository is for the Auth0 Candidate challenge. The requirement is to set-up dynamic security controls for EC2 instances. This service should:

- Shutdown a newly launched EC2 instance that uses a VPC’s default security group
- Shutdown a newly launched EC2 instance that has SSH open to the world

## Github Setup

This Github will contain code for the Auth0 Challenge Service.

### Github Actions

We use Github Actions to automate running python tests with pytest. Refer to .github/workflows/pytest.yml for details.

## Terraform Setup

We are using Terraform Cloud's Free Tier as a remote backend for running our terraform code. To initialize Terraform Cloud, ensure your TFC user has been invited to the "Ursys" Organization, and then execute `terraform login`. This will generate a User API token, which can then be used to authorize terraform CLI commands against the TFC Backend.

## Project Architecture

The Auth0 Challenge Service is made up of the following components:

![ChallengeArchitecture](static/challenge-architecture.png)

### Eventbridge

We deploy an eventbridge rule "capture-instance-remote" in every non-opt-in region in AWS. These rules listen for EC2 instance state changes, and if they are in the running state, send the event to the ec2-shutdown-bus event bus in us-east-1. Only entitites that have a specific role ARN are permitted to post messages to the ec2-shutdown-bus event bus.

There is an additional rule on the us-east-1 ec2-shutdown-bus that listens for EC2 state change events (populated by the "capture-instance-remote" rules). This rule sends the event to the AWS SQS queue "get-instance-info". We transform the event sent along the queue so that we only get the instance ID and region, and discard unnecessary values. This makes our lambda functions run faster, and reduces our cost infitesimally.

### AWS SQS

We make use of several AWS SQS queues to enable queueing in the event our lambda functions are overloaded (3500+ simultaneous executions), sending messages to dead letter queues on lambda errors for replays/redrives, and optionally supporting batching (see below).

#### Queues

- `get_instance_info_queue`: This queue is used to send messages to the lambda function that will retrieve instance information from AWS.
- `stop_instance_queue`: This queue is used to send messages to the lambda function that will stop an EC2 instance.
- `lock_instance_queue`: This queue is used to send messages to the lambda function that will lock an instance.

All of the above queues additionall yhave dead letter queues to handle event errors.

#### Batching

Enabling support for batching instances is as simple as changing the terraform lambda values: maximum_batching_window_in_seconds and maximum_batch_size. These are both set to 0 to maximize the speed at which the lambda function operates. However, the lambda functions can support batching of up to 10 instances at a time. This only makes sense if we want to optimize for costs instead of for time to execution.

### Lambda Functions

Lambda functions are used to perform the analysis, stopping, and locking of EC2 instances. The functions are:

- `evaluate_instances`: This function is used to evaluate the state of an EC2 instance and send a message to the appropriate queue -> function.
- `stop_instance`: This function will stop an instance sent to it by evaluate_instances. Instances are candidates for stopping if the instance in question has flagged security groups, has an ebs volume, does not belong to an autoscaling group, and is not a spot instance state. Additionally, if the stop_instance function fails, we will attempt to lock the instance before failing completely.
- `lock_instance`: This function will "lock" an instance if it has flagged security groups and does not have an ebs volume, does belong to an autoscaling group, or is a spot instance. evaluate_instances or stop_instance. "Locking" an instance entails removing the security group that was flagged on instance creation, and replacing it with a dummy security group that does nothing but allow an instance to emit traffic to itself.

Lambda functions are managed as docker containers, and are deployed to an Elastic Container Registry (ECR) in the us-east-1 region.

### Elastic Container Registry (ECR)

We have three ECR repositories:

- `evaluate_instance_repository`: This repository contains the docker image for the evaluate_instances lambda function.
- `stop_instance_repository`: This repository contains the docker image for the stop_instance lambda function.
- `lock_instance_repository`: This repository contains the docker image for the lock_instance lambda function.

#### Pushing Lambdas to ECR

1. Ensure docker is started and running
2. cd to the src/[lambda_name] directory
3. Build the docker image with `docker build -t [lambda_name] .`
4. Tag the image with `docker tag [lambda_name] [aws_account_id].dkr.ecr.us-east-1.amazonaws.com/[lambda_name]_repository`
5. Login to ECR with `aws ecr get-login-password | docker login --username AWS --password-stdin [aws_account_id].dkr.ecr.us-east-1.amazonaws.com`
6. Push the image to ECR with `docker push [aws_account_id].dkr.ecr.us-east-1.amazonaws.com/[lambda_name]_repository`

Note that you will need to run terraform apply to deploy the lambda functions once the image has been built. You can do this by navigating to Terraform Cloud and clicking "Actions -> Start New Plan".

## Monitoring

[A Custom Cloudwatch Dashboard](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards) has been created for this service and is available by clicking on the link.

## Pricing

### Eventbridge Pricing

[Eventbridge Pricing](https://aws.amazon.com/eventbridge/pricing/)
[Data Transfer Pricing](https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer)

AWS Eventbridge runs in all AWS regions that support EC2 instances, that are not opt-in only regions. Happily, all AWS Default Service Events, including EC2 instance state changes, are entirely free of charge. However, we are charged for cross-region events at standard AWS Data Transfer rates, at $0.09 USD per GB. While AWS does not publish the exact size of each AWS event, using a sample event payload (and bearing in mind there may be some fluctuation depending on the time an instance was started at), each event is approximately 388 bytes. Given that a gigabyte is 1 billion bytes, this means the cost of our eventbridge rule invocation, for all cross region AWS accounts, is approximately $0.00000003492 per event ((388 / 1e9) * 0.09). 

$1 USD is approximately 30 million instance start events.

### SQS Pricing

[SQS Pricing](https://aws.amazon.com/sqs/pricing/)

We have 3 SQS queues, and we are within the Free Tier for all of them. Each instance start event will traverse at least one, and possibly two or three SQS queues depending on if it an instance that is a candidate for stopping. The first million requests per month are free, and the next 100 billion requests per month are priced at $0.40 USD per million. Since each event is well under the 64KB payload chunk, we can assume each event results in only one billed request.

Data transfered between Amazon SQS and AWS Lambda within a single region is free of charge.

$1 USD is approximately 2.5 million instance start events.

### Lambda Pricing

[Lambda Pricing](https://aws.amazon.com/lambda/pricing/)

The average time to execute our lambda functions is on the order of 2.8 seconds for evaluate instances, and 1.7 seconds for the stop instances function. Our lambdas are all executing in us-east-1 on x86, which means a price of $0.0000166667 for every GB-second and $0.20 per 1M requests.

The evaluate_instances lambda function will execute on all instance launch events, and the stop_instance/lock_instance lambda will only execute when we hit a flagged instance. 

For our evaluate_instances lambda function, we will spend on average per execution:
$0.00000588 USD

$1 USD is approximately 200,000 instance start invocations.

For our stop_instance lambda function, we will spend on average per execution:
$0.00000357 USD

$1 USD is approximately 300,000 instance stop invocations.

### AWS Cloudwatch

[Cloudwatch Pricing](https://aws.amazon.com/cloudwatch/pricing/)

We do not use any custom Cloudwatch metrics or events, and all event logs, dashboards, and metrics are below the free tier limits.