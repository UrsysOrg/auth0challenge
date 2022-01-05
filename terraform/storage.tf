resource "aws_s3_bucket" "test_bucket" {
  bucket = "sara-auth0-tf-test-bucket"
  acl    = "private"

  tags = {
    Name        = "Sara Test Bucket"
  }
}
