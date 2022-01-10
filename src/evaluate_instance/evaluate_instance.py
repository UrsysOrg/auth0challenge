import json
import boto3
from botocore.exceptions import ClientError
from collections import defaultdict
import logging

### VARIABLES
STOP_QUEUE_NAME = "stop_instance_queue"
LOCK_QUEUE_NAME = "lock_instance_queue"
# We need this so we know which region to send our SQS messages to
DEFAULT_REGION  = "us-east-1"

### LOGGING
logging.basicConfig(level=logging.INFO)
log = logging.getLogger("ec2_shutdown_logger")
log.setLevel(logging.INFO)

### CLASSES
class SqsClient:
    '''Creates a SQS Client to handle API actions'''
    def __init__(self, region):
        self.client = boto3.client('sqs', region_name=region)
        self.region = region
   
    def get_queue_url(self, queue_name):
        '''Gets the URL of the queue'''
        try:
            response = self.client.get_queue_url(QueueName=queue_name)
            log.debug("Got queue url: {0}".format(response))
            return response['QueueUrl']
        except ClientError as error:
            log.error("Unable to get queue URL for queue: {0}, error: {1}".format(queue_name, error))
            return {}

    def send_message(self, queue_url, message):
        '''Sends a message to the queue'''
        try:
            response = self.client.send_message(QueueUrl=queue_url, MessageBody=message)
            log.debug("Sent message: {0}".format(response))
            return response
        except ClientError as error:
            log.error("Unable to send message to queue: {0}, error: {1}".format(queue_url, error))
            return {}

class Ec2Client:
    '''Creates a EC2 client to handle API actions'''
    def __init__(self, region):
        self.client = boto3.client('ec2', region_name=region)
        self.region = region

    def describe_instances(self, instance_ids):
        '''Describes instances given a instance ids, returns a list of instances'''
        try:
            response = self.client.describe_instances(InstanceIds=instance_ids)
            log.debug("Describe instances response: {0}".format(response))
            return response
        except ClientError as error:
            log.error("Unable to list instances, error: {0}".format(error))
            return {}
    def describe_security_groups(self, security_group_ids):
        '''Describes security groups given a security group ids, returns a list of security groups'''
        try:
            response = self.client.describe_security_groups(GroupIds=security_group_ids)
            log.debug("Describe security groups response: {0}".format(response))
            return response
        except ClientError as error:
            log.error("Unable to list security groups, error: {0}".format(error))
            return {}

class AutoscalerClient:
    '''Creates an Autoscaler client to handle API actions'''
    def __init__(self, region):
        self.client = boto3.client('autoscaling', region_name=region)
        self.region = region

    def describe_auto_scaling_instances(self, instance_ids):
        '''Given a list of instance IDs, determine if they are part of an ASG'''
        try:
            response = self.client.describe_auto_scaling_instances(InstanceIds=instance_ids)
            log.debug("Describe AutoScaling Response: {0}".format(response))
            return response
        except ClientError as error:
            log.error("Unable to list auto scaling instances, error: {0}".format(error))
            return {}

### FUNCTIONS

def route_instance_message(instancelist):
    '''Routes messages to SQS Queue'''
    log.info("Routing instance list {} to SQS queue...".format(instancelist))
    sqs_client = SqsClient(DEFAULT_REGION)
    lock_queue_url = sqs_client.get_queue_url(LOCK_QUEUE_NAME)
    stop_queue_url = sqs_client.get_queue_url(STOP_QUEUE_NAME)
    if lock_queue_url and stop_queue_url == False:
        raise ValueError("Unable to get queue URLs for lock and stop queues, aborting...")
    for instancedict in instancelist:
        for instance in instancedict:
            # on success or failure, we continue to the next instance in the dict
            message_body = json.dumps(instance)
            log.debug("Sending message: {0}".format(message_body))
            # For instances that are being stopped, we can safely fail to the lock queue
            if instance['action'] == 'stop':
                response = sqs_client.send_message(stop_queue_url, message_body)
                if response:
                    continue
                log.warn("Unable to send message to stop queue, attempting lock...")
                response = sqs_client.send_message(lock_queue_url, message_body)
                continue
            # For instances that are being locked, we have no failure options but the dead letter queue
            if instance['action'] == 'lock':
                response = sqs_client.send_message(lock_queue_url, message_body)
                if response:
                    continue
                log.error("Unable to send message to lock queue, aborting...")
                continue
            else:
                raise ValueError("Unable to route instance message, unknown action: {0}".format(instance['action']))

def stop_lock_instance(instance, flag, security_group_ids, vpc_id, region):
    '''Given an instance dict and its flag, evaluate whether to stop or lock'''
    # Check to see if the instance is part of an autoscaling group, if the response is empty, then it is not part of an ASG
    log.info("Analyzing instances for shutdown/lock...")
    autoscaler_client = AutoscalerClient(region)
    try:
        response = autoscaler_client.describe_auto_scaling_instances(instance_ids=[instance['InstanceId']])
    except ClientError as error:
        log.warn("Unable to look up instance in ASG, marking for locking. error: {0}".format(error))
        return {'instance_id': instance['InstanceId'], 'action': 'lock', 'flag': flag, "security_group_ids": security_group_ids, "region": region}
    # If we have an EBS volume, are not a spot instance, and do not have an ASG attached, we can safely shutdown
    if instance['RootDeviceType'] == 'ebs' and 'InstanceLifecycle' not in instance and response['AutoScalingInstances'] == []:
        log.info("Instance {0} has an EBS volume, is not in an ASG, and is not a spot instance, mark for stopping.".format(instance['InstanceId']))
        return {'instance_id': instance['InstanceId'], 'action': 'stop', 'flag': flag, "security_group_ids": security_group_ids, "vpc_id": vpc_id, "region": region}
    else:
        log.info("Instance {0} does not have an EBS volume, or is part of an ASG, or is a spot instance, mark for locking.".format(instance['InstanceId']))
        return {'instance_id': instance['InstanceId'], 'action': 'lock', 'flag': flag, "security_group_ids": security_group_ids, "vpc_id": vpc_id, "region": region}

# Takes as input a dictionary of security groups, parses for rules, and returns True or False if SSH is open
def has_ssh_open(security_groups):
    for sg in security_groups:
        for p in sg['IpPermissions']:
            # We need to check if the SG Rule actually refers to an IP protocol vs a security group, otherwise we get a key error when evaluating
            if 'FromPort' in p and 'ToPort' in p:
                if ((p['FromPort'] == 22 or p['FromPort'] == -1) and (p['ToPort'] == 22 or p['ToPort'] == -1)) or (p['FromPort'] <= 22 <= p['ToPort']):
                    if p['IpProtocol'] == 'tcp' and (p['IpRanges'][0]['CidrIp'] == '0.0.0.0/0' or p['IpRanges'][0]['CidrIp'] == '::/0'):
                        return True
    return False

# Takes as input a dictionary of security groups, parses for rules, and returns True or False if HTTP is open
def has_default_security_group(security_groups):
    for sg in security_groups:
        if sg['GroupName'] == 'default':
            return True
    return False

#
def check_security_groups(instance_id, security_group_ids, region):
    log.info("Checking security groups...")
    ec2_client = Ec2Client(region)
    response = ec2_client.describe_security_groups(security_group_ids)
    # Store the results of our security group analysis in vars so we don't need to re-run when evaluating truthiness
    ssh_open = has_ssh_open(response['SecurityGroups'])
    default_group = has_default_security_group(response['SecurityGroups'])
    if ssh_open and default_group:
        return {'instance_id': instance_id, 'action': 'analyze', 'flag': 'both'}
    if ssh_open:
        return {'instance_id': instance_id, 'action': 'analyze', 'flag': 'ssh'}
    if default_group:
        return {'instance_id': instance_id, 'action': 'analyze', 'flag': 'default'}
    return {'instance_id': instance_id, 'action': 'skip', 'flag': 'no_bad_sgs'}

# Takes as input an instance dictionary, parses for tags, and returns a dictionary with the instance ID and the action to take
def check_tags(instance):
    instancedict = {}
    if 'Tags' in instance:
        log.debug("instance: {0}" .format(instance))
        for t in instance['Tags']:
            log.debug("tag: {0}" .format(t))
            if t['Key'] == 'shutdown_service_excluded' and t['Value'] == 'True':
                instancedict = {'instance_id': instance['InstanceId'], 'action': 'skip', 'flag': 'excluded'}
                return instancedict
            else:
                continue
    instancedict = {'instance_id': instance['InstanceId'], 'action': 'analyze', 'flag': 'no_exclusion_tags'}
    return instancedict                                            

# Accepts a dictionary containing instance details, returns a list of dicts with the instance ID, action, and flag
def analyze_instances(response, region):
    instancelist = []
    for r in response['Reservations']:
        for i in r['Instances']:
            log.info("Checking instance: {0}".format(i['InstanceId']))
            # If the instance is already stopped by some other cause, we don't need to try again.
            if i['State']['Name'] == 'running':
                # CHECK TAGS
                log.info("Checking tags...")
                instance_tag_dict = check_tags(i)
                log.debug("Instance tag dict: {0}".format(instance_tag_dict))
                if instance_tag_dict['action'] == 'skip':
                    log.info("Skipping instance {0} due to exclusion tag...".format(i['InstanceId']))
                    continue
                # CHECK SECURITY GROUPS
                security_group_ids = []
                for sg in i['SecurityGroups']:
                    security_group_ids.append(sg['GroupId'])
                instance_sg_dict = check_security_groups(i['InstanceId'], security_group_ids, region)
                if instance_sg_dict['action'] == 'skip':
                    log.info("Skipping instance {0} due to no bad security groups...".format(i['InstanceId']))
                    continue
                else:
                    # ANALYZE FLAGGED INSTANCES
                    # stop_lock_instance returns a dict with the instance ID, action (stop/lock), flag (ssh/default/both), region
                    # security_group_ids and vpc_id are only used if we're locking an instance
                    vpc_id = i['VpcId']
                    instancelist.append(stop_lock_instance(i, instance_sg_dict['flag'], security_group_ids, vpc_id, region))
    return instancelist           


# Accepts a list of instance IDs, queries the AWS API for instance details, and returns a dictionary of the results
def list_instances(instance_ids, region):
    log.info("Listing instances in region: " + region)
    ec2_client = Ec2Client(region)
    try:
        response = ec2_client.describe_instances(instance_ids)
    except ClientError as error:
        # TODO: If we fail to lookup all instance IDs, try one instance at a time and skip the problematic instance
        log.warn("Unable to look up instance IDs in region: {0}, continuing with next region. error: {1}".format(region, error))
    return response

def lambda_handler(event, context):
    # Process event input and transform it into a dict of regions and instance IDs
    instance_map = defaultdict(list)
    instance_event_list = []
    for record in event['Records']:
        log.debug("Received Event Record Body {0}".format(record['body']))
        instance_event_dict = json.loads(record['body'])
        instance_event_list.append(instance_event_dict)
    # Transform the event dict into a dict of regions and instance IDs
    # Relies on defaultdict creating the key for region if it doesn't exist
    # and appending all instance IDs that match as a list to that key.
    for dict in instance_event_list:
        instance_map[dict['region']].append(dict['instance_id'])
    # Begin the analysis
    # We need to store the list here, since each region will have a different list of instances
    instance_list = []
    for region in instance_map:
        log.info("Checking instances in region: " + region)
        # Send the region, and the list of instance_ids associated with it to list_instances. Returns the response to the describe_instances API method
        describe_instances_response = list_instances(instance_map[region], region)
        log.debug("Instance response: {0}".format(describe_instances_response))
        # Analyze the instance details, and return a list of dicts with the instance ID, action, and flag which we append to our instance_list
        instance_list.append(analyze_instances(describe_instances_response, region))
        log.debug("Instance list: {0}".format(instance_list))
    if len(instance_list[0]) == 0:
        log.info("No instances to route, exiting.")
        return
    else:
        route_instance_message(instance_list)
        log.info("Finished processing instances!")
        return {
            'statusCode': 200,
            'body': json.dumps('Instances processed successfully!')
        }
