provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "useast2"
  region = "us-east-2"
}

provider "aws" {
  alias  = "uswest1"
  region = "us-west-1"
}

provider "aws" {
  alias  = "uswest2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "apsouth1"
  region = "ap-south-1"
}

provider "aws" {
  alias = "apsoutheast1"
  region = "ap-southeast-1"
}
provider "aws" {
  alias = "apsoutheast2"
  region = "ap-southeast-2"
}

provider "aws" {
  alias  = "apnortheast1"
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "apnortheast2"
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "apnortheast3"
  region = "ap-northeast-3"
}

provider "aws" {
  alias  = "cacentral1"
  region = "ca-central-1"
}

provider "aws" {
  alias  = "eucentral1"
  region = "eu-central-1"
}

provider "aws" {
  alias  = "euwest1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "euwest2"
  region = "eu-west-2"
}

provider "aws" {
  alias  = "euwest3"
  region = "eu-west-3"
}

provider "aws" {
  alias  = "eunorth1"
  region = "eu-north-1"
}

provider "aws" {
  alias  = "saeast1"
  region = "sa-east-1"
}


### OPT IN REGIONS
#provider "aws" {
#  alias  = "afsouth1"
#  region = "af-south-1"
#}

#provider "aws" {
#  alias  = "apeast1"
#  region = "ap-east-1"
#}

#provider "aws" {
#  alias  = "apsoutheast3"
#  region = "ap-southeast-3"
#}

#provider "aws" {
#  alias = "eusouth1"
#  region = "eu-south-1"
#}

#provider "aws" {
#  alias = "mesouth1"
#  region = "me-south-1"
#}
