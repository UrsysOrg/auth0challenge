import pytest
import json

test_instance_id = "i-0c8f8f8f8f8f8f8f8"
test_region = "us-east-1"
with open('tests/describe_instance_response.json') as f:
    describe_instance_response = json.load(f)

with open('tests/describe_security_groups_response.json') as f:
    describe_security_groups_response = json.load(f)

empty_asg_response = {'AutoScalingInstances': []}
def test_conf():
    assert True