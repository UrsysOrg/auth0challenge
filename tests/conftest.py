import json

TEST_INSTANCE_ID = "i-0c8f8f8f8f8f8f8f8"
TEST_REGION = "us-east-1"
with open('tests/describe_instance_response.json', encoding='utf-8') as f:
    describe_instance_response = json.load(f)

with open('tests/describe_security_groups_response.json', encoding='utf-8') as f:
    describe_security_groups_response = json.load(f)

empty_asg_response = {'AutoScalingInstances': []}
def test_conf():
    '''Simply shows that the test config is working'''
    assert True
    