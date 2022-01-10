import src.evaluate_instance.evaluate_instance as evaluate_instance
import mock
import pytest
from conftest import test_instance_id, test_region, describe_instance_response, describe_security_groups_response, empty_asg_response


### TEST TAGS
def test_check_tags_excluded():
    instance_dict = {'InstanceId': test_instance_id, 'Tags': [{'Key': 'shutdown_service_excluded', 'Value': 'True'}]}
    expected_result = {'instance_id': test_instance_id, 'action': 'skip', 'flag': 'excluded'}
    result = evaluate_instance.check_tags(instance_dict)
    assert result == expected_result
def test_check_tags_not_excluded():
    instance_dict = {'InstanceId': test_instance_id, 'Tags': [{'Key': 'shutdown_service_excluded', 'Value': 'False'}]}
    expected_result = {'instance_id': test_instance_id, 'action': 'analyze', 'flag': 'no_exclusion_tags'}
    result = evaluate_instance.check_tags(instance_dict)
    assert result == expected_result
def test_check_tags_not_exist():
    instance_dict = {'InstanceId': test_instance_id}
    expected_result = {'instance_id': test_instance_id, 'action': 'analyze', 'flag': 'no_exclusion_tags'}
    result = evaluate_instance.check_tags(instance_dict)
    assert result == expected_result

### TEST SECURITY GROUPS
def test_has_ssh_open():
    security_groups = describe_security_groups_response['SecurityGroups']
    expected_result = True
    result = evaluate_instance.has_ssh_open(security_groups)
    assert result == expected_result

def test_has_default_security_group():
    security_groups = [{'GroupName': 'default'}]
    expected_result = True
    result = evaluate_instance.has_default_security_group(security_groups)
    assert result == expected_result

def test_has_other_security_groups():
    security_groups = describe_security_groups_response['SecurityGroups']
    expected_result = False
    result = evaluate_instance.has_default_security_group(security_groups)
    assert result == expected_result

### TEST DESCRIBE_SECURITY_GROUPS

### TEST DESCRIBE_INSTANCE
    
@mock.patch('boto3.client')
def test_check_security_groups(mock_boto_client):
    mock_boto_client.return_value = mock_boto_client
    mock_boto_client.describe_security_groups.return_value = describe_security_groups_response
    expected_result = {'instance_id': test_instance_id, 'action': 'analyze', 'flag': 'ssh'}
    result = evaluate_instance.check_security_groups(test_instance_id, describe_security_groups_response['SecurityGroups'][0]['GroupId'], test_region)
    assert result == expected_result

@mock.patch('boto3.client')
#class TestStopLock(unittest.TestCase):
def test_check_stop_lock_no_autoscale(mock_boto_client):
    instance_dict = {'InstanceId': test_instance_id, 'RootDeviceType': 'ebs'}
    mock_boto_client.return_value = mock_boto_client
    mock_boto_client.describe_auto_scaling_instances.return_value = empty_asg_response
    expected_result = {'instance_id': test_instance_id, 'action': 'stop', 'flag': 'test_flag', 'security_group_ids': ['test_group_id'], 'vpc_id': 'test_vpc_id', 'region': test_region}
    result = evaluate_instance.stop_lock_instance(instance_dict, "test_flag", ["test_group_id"], "test_vpc_id", test_region)
    assert result == expected_result

@mock.patch('boto3.client')
def test_check_stop_lock_autoscale(mock_boto_client):
    instance_dict = {'InstanceId': test_instance_id, 'RootDeviceType': 'ebs'}
    response = {'AutoScalingInstances': [{'AutoScalingGroupName': 'test_autoscale_group', 'LifecycleState': 'InService'}]}
    mock_boto_client.return_value = mock_boto_client
    mock_boto_client.describe_auto_scaling_instances.return_value = response
    
    expected_result = {'instance_id': test_instance_id, 'action': 'lock', 'flag': 'test_flag', 'security_group_ids': ['test_group_id'], 'vpc_id': 'test_vpc_id', 'region': test_region}
    result = evaluate_instance.stop_lock_instance(instance_dict, "test_flag", ["test_group_id"], "test_vpc_id", test_region)
    assert result == expected_result

#class TestListInstances(unittest.TestCase):
@mock.patch('boto3.client')    
def test_list_instances(mock_boto_client):
    instance_list = [test_instance_id]
    mock_boto_client.return_value = mock_boto_client
    mock_boto_client.describe_instances.return_value = describe_instance_response
    expected_result = describe_instance_response
    result = evaluate_instance.list_instances(instance_list, test_region)
    assert result == expected_result
