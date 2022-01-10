import json
import logging
import boto3
from botocore.exceptions import ClientError

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
    '''Instantiates a new EC2 client for making API calls'''
    def __init__(self, region):
        self.client = boto3.client('ec2', region_name=region)
        self.region = region

    def get_security_group_ids(self, filter):
        '''Accepts as input the filter to use in the describe_security_groups call'''
        try:
            log.info("Getting security groups, filter: {0}".format(filter))
            response = self.client.describe_security_groups(Filters=filter)
            log.debug("Describe security groups response: {}".format(response))
            return response
        except ClientError as error:
            raise ValueError("Unable to describe security groups, error: {0}".format(error))

    def create_dummy_security_group(self, instance_id, vpc_id):
        '''Creates a dummy security group for the instance
        We want to remove access to the SSH and default SGs, but can't do so if
        they are the only security groups attached to the instance.
        This method creates a security group which effectively does nothing,'''
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
                log.info("Found existing dummy security group: {0}, returning ID".format(dummy_response['SecurityGroups'][0]['GroupId']))
                return dummy_response['SecurityGroups'][0]['GroupId']
            log.error("Unable to create dummy security group, error: {0}".format(error))
            raise ValueError("Unable to create dummy security group, error: {0}".format(error))

    def authorize_rule_for_dummy_group(self, sg_id):
        '''To create a security group that does nothing, create a rule which allows egress traffic to the new SG
        This is similar behaviour to the VPC default SG, but since it's unique to the instance, we don't permit unnecessary access.'''
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
        '''Accepts a list of security group IDs and an instance ID,
        modifies the instance to have the listed security groups'''
        try:
            response = self.client.modify_instance_attribute(InstanceId=instance_id, Groups=sg_ids)
            log.info("Modified security groups: {0}".format(response))
            return response
        except ClientError as error:
            raise ValueError("Unable to modify security groups, error: {0}".format(error))

def modify_security_groups(sg_ids, instance_id, region):
    '''Calls modify_security_groups on the EC2 client'''
    try:
        ec2_client = Ec2Client(region)
        response = ec2_client.modify_security_groups(sg_ids, instance_id)
        log.info("Modified security groups: {0}".format(response))
        return "Successfully Locked Instance"
    except ClientError as error:
        raise ValueError("Unable to modify security groups, error: {0}".format(error))

def remove_duplicates(input_list, bad_group_list):
    '''Compares the list of previous security groups to the list of bad security groups
    converts lists to sets and removes duplicates from instance_dict['security_group_ids'] set
    returns a new list with only the security groups that are not in the bad_group_list set'''
    new_list = set(input_list).difference(set(bad_group_list))
    return new_list

def lock_ssh(instance_dict, filter):
    '''Accepts the instance dict as an input, gets the security groups ids with open ssh,
    locks the instance by removing the bad SG and adding the dummy SG'''
    ssh_group_list = []
    ec2_client = Ec2Client(instance_dict['region'])
    response = ec2_client.get_security_group_ids(filter)
    for security_group in response['SecurityGroups']:
        ssh_group_list.append(security_group['GroupId'])
    log.info("Bad group list: {}".format(ssh_group_list))
    # Remove the flagged open SSH security groups from the list
    new_sg_list = list(remove_duplicates(instance_dict['security_group_ids'], ssh_group_list))
    # add dummy sg ID to the list
    new_sg_list.append(ec2_client.create_dummy_security_group(instance_dict['instance_id'], instance_dict['vpc_id']))
    # call modify_security_groups
    modify_security_groups(new_sg_list, instance_dict['instance_id'], instance_dict['region'])
    return

def lock_default(instance_dict, filter):
    '''Accepts the instance dict as an input, gets the security group id for the default SG,
    locks the instance by removing the default SG and creating a new dummy security group'''
    default_group_list = []
    ec2_client = Ec2Client(instance_dict['region'])
    response = ec2_client.get_security_group_ids(filter)
    for security_group in response['SecurityGroups']:
        default_group_list.append(security_group['GroupId'])
    log.info("Bad group list: {}".format(default_group_list))
    new_sg_list = list(remove_duplicates(instance_dict['security_group_ids'], default_group_list))
    new_sg_list.append(ec2_client.create_dummy_security_group(instance_dict['instance_id'], instance_dict['vpc_id']))
    log.info("New SG list: {}".format(new_sg_list))
    modify_security_groups(new_sg_list, instance_dict['instance_id'], instance_dict['region'])
    return 

# TODO: Instead of repeating the same logic, can we reorganize lock_ssh and lock_default to be more DRY?
# This would require moving the "create_dummy_security_group" method out of the functions
def lock_both(instance_dict, filterdefault, filterssh):
    '''If the instance has both open SSH and default security groups, lock both'''
    get_default_sg_filter = filterdefault
    get_ssh_sg_filter = filterssh
    group_list = []
    ec2_client = Ec2Client(instance_dict['region'])
    # Query for default group IDs
    default_response = ec2_client.get_security_group_ids(get_default_sg_filter)
    log.info("Default group list: {}".format(default_response))
    for security_group in default_response['SecurityGroups']:
        log.info("SG: {}".format(security_group))
        group_list.append(security_group['GroupId'])
    # Query for SSH Group IDs
    ssh_response = ec2_client.get_security_group_ids(get_ssh_sg_filter)
    for security_group in ssh_response['SecurityGroups']:
        group_list.append(security_group['GroupId'])
    # Remove the flag groups from the list
    log.info("Bad Group list: {}".format(group_list))
    new_sg_list = list(remove_duplicates(instance_dict['security_group_ids'], group_list))
    new_sg_list.append(ec2_client.create_dummy_security_group(instance_dict['instance_id'], instance_dict['vpc_id']))
    # Modify instance with the good SG list
    modify_security_groups(new_sg_list, instance_dict['instance_id'], instance_dict['region'])

# Accepts the instance dict as input, sets our filters, and calls the appropriate lock function
def lock_instance(instance_dict):
    '''Accepts the instance dict as input, sets filters, and calls the appropriate lock function'''
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
    log.error("No flag found for instance {0}, review evaluate_instance/lambda logs".format(instance_dict['instance_id']))
    return False

def lambda_handler(event, context):
    '''Receives an event body containing instance id, region, and other flags.
    We can expect only one record in event['Records']'''
    for record in event['Records']:
        log.info("Received record body: {}".format(record['body']))
        instance_dict = json.loads(record['body'])
        lock_instance(instance_dict)
        log.info("Locked instance: {0}".format(instance_dict['instance_id']))
    return {
        'statusCode': 200,
        'body': json.dumps('Instances processed successfully!')
    }
