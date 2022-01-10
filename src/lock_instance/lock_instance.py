import json
import logging
from warnings import filters
import boto3
from botocore.exceptions import ClientError
import re

logging.basicConfig(level=logging.INFO)

log = logging.getLogger("ec2_lock_logger")
log.setLevel(logging.INFO)

# Receives a dict with the following keys:
# {
#  'instance_id': 'i-0c8f8f8f8f8f8f8f8',
#  'action': 'lock',
#  'security_group_ids': ['sg-0c8f8f8f8f8f8f8f8', 'sg-0c8f8f8f8f8f8f8f8'],
#  'vpc_id': 'vpc-0c8f8f8f8f8f8f8f8',
#  'region': 'us-east-1'  
#  'flag': 'ssh | default | both'
#}

class Ec2Client:
    def __init__(self, region):
        self.client = boto3.client('ec2', region_name=region)
        self.region = region
        
    def get_security_group_ids(self, filter):
        try:
            log.info("Getting security groups, filter: {0}".format(filter))
            response = self.client.describe_security_groups(Filters=filter)
            log.debug("Describe security groups response: {}".format(response))
            return response
        except ClientError as error:
            raise ValueError("Unable to describe security groups, error: {0}".format(error))
                
    # We want to remove the SSH and default SGs, but what happens if they are the only security groups attached to the instance?
    # in that case, we need to create a new SG that does effectively nothing.
    # returns the new SG ID as a list
    def create_dummy_security_group(self, instance_id, vpc_id):
        try:
            log.info("Creating dummy security group for instance: {0}".format(instance_id))
            response = self.client.create_security_group(
                GroupName='dummy_security_group ' + instance_id,
                Description='dummy security group for instance ' + instance_id,
                VpcId=vpc_id,
                TagSpecifications=[{'ResourceType': 'security-group', 'Tags': [{'Key': 'shutdown_service_dummy_group', 'Value': 'True'}]}]
            )
            log.info("Created dummy security group: {0}".format(response))
            return response['GroupId']
        except ClientError as error:
            if error.response['Error']['Code'] == 'InvalidGroup.Duplicate':
                # TODO: Move this before the create_dummy_security_group call
                dummy_response = self.get_security_group_ids(filter=[{'Name': 'group-name', 'Values': ['dummy_security_group ' + instance_id]}])
                log.info("Found existing dummy security group: {0}, returning ID".format(dummy_response))
                return dummy_response['SecurityGroups'][0]['GroupId']
            log.error("Unable to create dummy security group, error: {0}".format(error))
            raise ValueError("Unable to create dummy security group, error: {0}".format(error))
    
    # To create a security group that effectively does nothing, create a rule which allows inbound/egress traffic to the new SG
    # this is ironically the exact behaviour of the VPC default security group, but since it's unique to the instance, it's fine in this case.
    def authorize_rule_for_dummy_group(self, sg_id):
        try:
            response = self.client.authorize_security_group_egress(
                GroupId=sg_id,
                IpPermissions=[{'FromPort': -1, 'ToPort': -1, 'IpProtocol': '-1', 'IpRanges': [{'CidrIp': sg_id}], 'Ipv6Ranges': [{'CidrIpv6': sg_id}]}]
            )
            log.info("Authorized rule for dummy security group: {0}".format(response))
            return response
        except ClientError as error:
            log.error("Unable to authorize rule for dummy security group, error: {0}".format(error))
            raise ValueError("Unable to create authorize rule for dummy security group, error: {0}".format(error))
    
    # Accepts a lsit of security group IDs and an instance ID, modifies the instance to have the listed security groups
    def modify_security_groups(self, sg_ids, instance_id):
        try:
            response = self.client.modify_instance_attribute(InstanceId=instance_id, Groups=sg_ids)
            log.info("Modified security groups: {0}".format(response))
            return response
        except ClientError as error:
            raise ValueError("Unable to modify security groups, error: {0}".format(error))
        
    
# Calls the EC2 API to lock the instance by modifying security groups
def modify_security_groups(sg_ids, instance_id, region):
    try:
        ec2_client = Ec2Client(region)
        response = ec2_client.modify_security_groups(sg_ids, instance_id)
        log.info("Modified security groups: {0}".format(response))
        return "Successfully Locked Instance"
    except ClientError as error:
        raise ValueError("Unable to modify security groups, error: {0}".format(error))
    
# Compare the list of previous instance security groups to the list of bad security groups
# convert lists to sets and remove duplicates from instance_dict['security_group_ids'] set
# returns a new list with only the security groups that are not in the bad_group_list set
def remove_duplicates(input_list, bad_group_list):
    new_list = set(input_list).difference(set(bad_group_list))
    return new_list

# Accepts the instance dict as an input, gets the security groups with open SSH, creates a new dummy security group
# Modifies the instance to have dummy SG + non-SSH allowing SGs
# returns "successfully locked instance" or error message
def lock_ssh(instance_dict, filter):
    ssh_group_list = []
    ec2_client = Ec2Client(instance_dict['region'])
    response = ec2_client.get_security_group_ids(filter)
    for sg in response['SecurityGroups']:
        ssh_group_list.append(sg['GroupId'])
    log.info("Bad group list: {}".format(ssh_group_list))
    # Remove the flagged open SSH security groups from the list
    new_sg_list = remove_duplicates(instance_dict['security_group_ids'], ssh_group_list)
    # add dummy sg ID to the list
    new_sg_list.append(ec2_client.create_dummy_security_group(instance_dict['instance_id'], instance_dict['vpc_id']))
    # call modify_security_groups
    modify_security_groups(new_sg_list, instance_dict['instance_id'], instance_dict['region'])
    return

def lock_default(instance_dict, filter):
    default_group_list = []
    ec2_client = Ec2Client(instance_dict['region'])
    response = ec2_client.get_security_group_ids(filter)
    for sg in response['SecurityGroups']:
        default_group_list.append(sg['GroupId'])
    log.info("Bad group list: {}".format(default_group_list))
    new_sg_list = remove_duplicates(instance_dict['security_group_ids'], default_group_list)
    new_sg_list.append(ec2_client.create_dummy_security_group(instance_dict['instance_id'], instance_dict['vpc_id']))
    log.info("New SG list: {}".format(new_sg_list))
    modify_security_groups(new_sg_list, instance_dict['instance_id'], instance_dict['region'])
    return    

# TODO: Instead of repeating the same logic, can we reorganize lock_ssh and lock_default to be more DRY?
# This would require moving the "create_dummy_security_group" method out of the functions
def lock_both(instance_dict, filterdefault, filterssh):
    get_default_sg_filter = filterdefault
    get_ssh_sg_filter = filterssh
    group_list = []
    ec2_client = Ec2Client(instance_dict['region'])
    # Query for default group IDs
    default_response = ec2_client.get_security_group_ids(get_default_sg_filter)
    log.info("Default group list: {}".format(default_response))
    for sg in default_response['SecurityGroups']:
        log.info("SG: {}".format(sg))
        group_list.append(sg['GroupId'])
    # Query for SSH Group IDs
    ssh_response = ec2_client.get_security_group_ids(get_ssh_sg_filter)
    for sg in ssh_response['SecurityGroups']:
        group_list.append(sg['GroupId'])
    # Remove the flag groups from the list
    log.info("Bad Group list: {}".format(group_list))
    new_sg_list = list(remove_duplicates(instance_dict['security_group_ids'], group_list))
    new_sg_list.append(ec2_client.create_dummy_security_group(instance_dict['instance_id'], instance_dict['vpc_id']))
    # Modify instance with the good SG list
    modify_security_groups(new_sg_list, instance_dict['instance_id'], instance_dict['region'])
    return

# Accepts the instance dict as input, sets our filters, and calls the appropriate lock function
def lock_instance(instance_dict):
    get_default_sg_filter = [{'Name': 'vpc-id', 'Values': [instance_dict['vpc_id']], 'Name': 'group-name', 'Values': ['default']}]
    get_ssh_sg_filter = [{'Name': 'vpc-id', 'Values': [instance_dict['vpc_id']], 'Name': 'ip-permission.to-port', 'Values': ['22', '-1'], 'Name': 'ip-permission.cidr', 'Values': ['0.0.0.0/0'], 'Name': 'ip-permission.ipv6-cidr', 'Values': ['::/0']}]
    if instance_dict['flag'] == 'ssh':
        lock_ssh(instance_dict, get_ssh_sg_filter)
        return True
    elif instance_dict['flag'] == 'default':
        lock_default(instance_dict, get_default_sg_filter)
        return True
    elif instance_dict['flag'] == 'both':
        lock_both(instance_dict, get_default_sg_filter, get_ssh_sg_filter)
        return True
    else:
        log.warn("No flag found for instance {0}, review evaluate_instance/lambda logs".format(instance_dict['instance_id']))
        return False
        
        
def lambda_handler(event, context):
    # We receive an event body, which contains the instance id, region, 
    # other flags we only care about on lock
    # We can expect only one record in event['Records']
    for record in event['Records']:
        log.info("Received record body: {}".format(record['body']))
        instance_dict = json.loads(record['body'])
        lock_instance(instance_dict)
        log.info("Locked instance: {0}".format(instance_dict['instance_id']))
    return {
        'statusCode': 200,
        'body': json.dumps('Instances processed successfully!')
    }


### LOCAL TESTING
#if __name__ == '__main__':
#    event = {'Records': [{'messageId': '14281587-12ea-4717-a939-10bdc9df1f2c', 'receiptHandle': 'AQEBViyglCRntzWowBRVZS4cfTVarGHVBuYG/9k15TffeDn8I9EaSOluBNTL3dkKva81M1E5EeyYzp50KyHJOm/PmIh78NfoJFuQO4b9Q36FdnaU3o1gl8lajNjW0uHRDFDlLUudJsDn+N3ErA4HeZeZbFBMMa5zhvzqfAFOOWFrHyQ/nCGOvwS/Xb3sohbO8zV+pdVDRH4yGDVJOc3iq9O7ZzJR9Hib9y2A2dOzyliFd9shU4cG7rhXmFAcNEVsmVMiF1aN/8KV+i2TNb03hyEAFM1pHQv9ks0owwMEAEM2CPacujPXUp9aS5FmLq6inWDCkj7NVJcRRlxrHmcwckjs7sC0Tw7IQCqurCiN3atGSYF5BmZv6raJr9sWeBkVt/qI8r70q/h1nKr+6OQumW1OeQ==', 'body': '{"instance_id": "i-045f97c8a6021e2de", "action": "stop", "flag": "both", "security_group_ids": ["sg-023ad61b9955eaca4"], "vpc_id": "vpc-03420aacb89ba100f", "region": "us-east-1"}', 'attributes': {'ApproximateReceiveCount': '1', 'SentTimestamp': '1641767367754', 'SenderId': 'AIDAS6BUSUZTPW4YGHT7Z', 'ApproximateFirstReceiveTimestamp': '1641767367755'}, 'messageAttributes': {}, 'md5OfBody': '65e1c52a71caeac7b1a0710db6f5bfe0', 'eventSource': 'aws:sqs', 'eventSourceARN': 'arn:aws:sqs:us-east-1:201973737062:lock_instance_queue', 'awsRegion': 'us-east-1'}]}
#    lambda_handler(event, "foo")
