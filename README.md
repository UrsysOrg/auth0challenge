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
