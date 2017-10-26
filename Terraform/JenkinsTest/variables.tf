variable "access_key" {}
variable "secret_key" {}
variable "region" {
  default = "us-east-2"
}

terraform {
    backend "s3" {
        encrypt = "true"
    }
}

