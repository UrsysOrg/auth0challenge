provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "uswest1"
  region = "us-west-1"
}