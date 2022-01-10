import json
import logging
import boto3
from botocore.exceptions import ClientError

LOCK_QUEUE_NAME = "lock_instance_queue"
DEFAULT_REGION = "us-east-1"
logging.basicConfig(level=logging.INFO)
log = logging.getLogger("ec2_stop_logger")
log.setLevel(logging.INFO)

### CLASSES
class SqsClient:
    '''Instantiates a SQS client for API calls'''
    def __init__(self, region):
        self.client = boto3.client('sqs', region_name=region)
        self.region = region

    def get_queue_url(self, queue_name):
        '''Accepts a queue name, returns the queue URL'''
        try:
            response = self.client.get_queue_url(QueueName=queue_name)
            log.debug("Got queue url: {0}".format(response))
            return response['QueueUrl']
        except ClientError as error:
            log.error("Unable to get queue URL for queue: {0}, error: {1}".format(queue_name, error))
            return {}

    def send_message(self, queue_url, message):
        '''Accepts a queue URL and a message, sends the message to the queue'''
        try:
            response = self.client.send_message(QueueUrl=queue_url, MessageBody=message)
            log.debug("Sent message: {0}".format(response))
            return response
        except ClientError as error:
            log.error("Unable to send message to queue: {0}, error: {1}".format(queue_url, error))
            return {}

class Ec2Client:
    '''Instantiates an EC2 client for API calls'''
    def __init__(self, region):
        self.client = boto3.client('ec2', region_name=region)
        self.region = region

    def stop_instance(self, instance_id_list):
        '''Accepts a list of instance IDs, stops the instances'''
        try:
            response = self.client.stop_instances(InstanceIds=instance_id_list)
            log.info("Stopped instances: {}".format(instance_id_list))
            return response
        except ClientError as error:
            log.error("Error stopping instance: {}".format(error))
            return {}


### FUNCTIONS
def send_instance_to_lock_queue(message, region):
    '''Accepts a message and region, sends the message to the lock queue'''
    sqs_client = SqsClient(region)
    queue_url = sqs_client.get_queue_url(LOCK_QUEUE_NAME)
    if queue_url:
        sqs_response = sqs_client.send_message(queue_url, message)
        if sqs_response:
            log.info("Successfully sent message to lock queue: {}".format(message))
            return True
        else:
            log.error("Error sending message to lock queue: {}".format(message))
            return False
    else:
        log.error("Unable to get queue url for queue: {0}".format(LOCK_QUEUE_NAME))
        return False

def stop_instance(instance_id, region):
    '''Accepts an instance ID and region, stops the instance'''
    ec2_client = Ec2Client(region)
    response = ec2_client.stop_instance([instance_id])
    if response:
        log.info("Stopped instance: {}".format(instance_id))
        log.debug("Response from stop_instance: {}".format(response))
        return True
    log.error("Error stopping instance, sending to lock queue: {}".format(instance_id))
    return False

def lambda_handler(event, context):
    '''Accepts an event from SQS, which contains instance ID, region,
    and other flags we only care about on lock. We can expect only
    one record in event['Records']'''
    for record in event['Records']:
        log.debug("Received event: {}".format(record))
        instance_dict = json.loads(record['body'])
        stop_result = stop_instance(instance_dict['instance_id'], instance_dict['region'])
        if stop_result:
            log.info("Successfully stopped instance, exiting")
            return {
                'statusCode': 200,
                'body': json.dumps('Successfully stopped instance!')
            }
        log.info("Error stopping instance, sending to lock queue")
        send_instance_to_lock_queue(record['body'], instance_dict['region'])
        return {
            'statusCode': 200,
            'body': json.dumps('Successfully sent instance to lock queue!')
        }
