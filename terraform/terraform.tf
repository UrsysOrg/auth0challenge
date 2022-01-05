terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.70.0"
    }
  }

  required_version = ">= 1.1.0"
}

terraform {
  cloud {
    organization = "Ursys"
    workspaces {
      name = "Auth0ChallengeService"
    }
  }
}
