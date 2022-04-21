variable "aws_profile" {
  description = "Defines AWS profile to be used"
  type        = string
  default     = "aroaws"
}

variable "aws_region" {
  description = "Defines AWS region to be used"
  type        = string
  default     = "eu-central-1"
}

variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "lfs258-aroweb"
}

variable "key_name" {
  description = "Assign existing SSH Keypair as defined in AWS"
  type        = string
  default     = "aroweb"
}

variable "no_cp" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "no_wn" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}